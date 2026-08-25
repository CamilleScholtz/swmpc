//
//  ArtworkModeCommands.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import Foundation

/// Commands specific to artwork mode connections.
public extension ConnectionManager where Mode == ArtworkMode {
    /// Executes an artwork operation on a temporary connection with automatic
    /// cleanup.
    ///
    /// - Parameter operation: A closure that receives a connected
    ///                        `ConnectionManager<ArtworkMode>` and performs
    ///                        operations on it.
    /// - Returns: The result of the operation closure.
    /// - Throws: An error if the connection fails or if the operation throws.
    static func artwork<T: Sendable>(_ operation: @Sendable (
        ConnectionManager<ArtworkMode>,
    ) async throws -> T) async throws -> T {
        try await withConnection { manager in
            try await manager.raiseBinaryLimit()

            return try await operation(manager)
        }
    }

    /// Raises the server's binary response chunk size from the default 8 KB
    /// to reduce the number of round trips needed to transfer large artwork.
    ///
    /// The `binarylimit` command is only available since MPD 0.22.4; on older
    /// servers this is a no-op.
    ///
    /// - Throws: An error if the command fails on a supporting server.
    private func raiseBinaryLimit() async throws {
        guard supports(.binaryLimit) else {
            return
        }

        try await run(["binarylimit 131072"])
    }

    /// Retrieves artwork data with automatic fallback based on the server's
    /// artwork getter configuration.
    ///
    /// This method tries each configured MPD command in order (e.g., albumart
    /// then readpicture) and returns the first successful result. Commands the
    /// server is too old for are skipped: `albumart` arrived in MPD 0.21 and
    /// `readpicture` in 0.22.
    ///
    /// - Parameter file: The file path representing the artwork resource.
    /// - Returns: A `Data` object containing the complete binary artwork data.
    /// - Throws: `ConnectionManagerError.unsupportedByServer` if the server
    ///           has no artwork command at all, or an error if all available
    ///           methods fail to retrieve artwork.
    func getArtworkData(for file: String) async throws -> Data {
        let commands = (ConnectionConfiguration.server?.artworkGetter.commands
            ?? [.albumArt])
            .filter { supports($0.feature) }

        guard !commands.isEmpty else {
            throw ConnectionManagerError.unsupportedByServer(
                "artwork requires MPD \(ProtocolFeature.albumArt.minimumVersion) or later",
            )
        }

        var lastError: Error?

        for command in commands {
            do {
                return try await fetchArtworkChunks(for: file, using: command)
            } catch let error as ConnectionManagerError {
                if case .protocolViolation = error {
                    lastError = error
                    continue
                }

                throw error
            }
        }

        throw lastError ?? ConnectionManagerError.malformedResponse(
            "No artwork found",
        )
    }

    /// Fetches artwork data in chunks from the media server using a specific
    /// MPD command.
    ///
    /// - Parameters:
    ///   - file: The file path representing the artwork resource on the server.
    ///   - command: The MPD command to use.
    /// - Returns: A `Data` object containing the complete binary artwork data.
    /// - Throws: An error if the server response is malformed, if the read
    ///           operation fails, or if other connection related errors occur.
    private func fetchArtworkChunks(for file: String, using command:
        ArtworkCommand) async throws -> Data
    {
        var data = Data()
        var offset = 0
        var totalSize: Int?

        while true {
            try await writeLine("\(command.rawValue) \(escape(file)) \(offset)")

            var chunkSize: Int?

            while chunkSize == nil {
                let line = try await readLine()
                let (key, value) = try parseLine(line)

                switch key {
                case "size":
                    totalSize = Int(value)
                case "binary":
                    chunkSize = Int(value)
                default:
                    break
                }
            }

            guard let chunkSize else {
                throw ConnectionManagerError.malformedResponse(
                    "Missing chunk size",
                )
            }

            let binaryChunk = try await readFixedLengthData(chunkSize)
            data.append(binaryChunk)

            while true {
                let line = try await readLine()
                if line.hasPrefix("OK") {
                    break
                }
            }

            offset += chunkSize

            if offset >= (totalSize ?? 0) {
                return data
            }

            guard chunkSize > 0 else {
                throw ConnectionManagerError.malformedResponse(
                    "Received empty binary chunk before end of data",
                )
            }
        }
    }
}
