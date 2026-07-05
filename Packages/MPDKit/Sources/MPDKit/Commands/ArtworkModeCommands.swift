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
        try await withConnection(operation)
    }

    /// Retrieves artwork data with automatic fallback based on the server's
    /// artwork getter configuration.
    ///
    /// This method tries each configured MPD command in order (e.g., albumart
    /// then readpicture) and returns the first successful result.
    ///
    /// - Parameter file: The file path representing the artwork resource.
    /// - Returns: A `Data` object containing the complete binary artwork data.
    /// - Throws: An error if all configured methods fail to retrieve artwork.
    func getArtworkData(for file: String) async throws -> Data {
        let commands = ConnectionConfiguration.server?.artworkGetter.commands
            ?? ["albumart"]
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
    ///   - command: The MPD command to use (either "albumart" or
    ///              "readpicture").
    /// - Returns: A `Data` object containing the complete binary artwork data.
    /// - Throws: An error if the server response is malformed, if the read
    ///           operation fails, or if other connection related errors occur.
    private func fetchArtworkChunks(for file: String, using command: String)
        async throws -> Data
    {
        var data = Data()
        var offset = 0
        var totalSize: Int?

        while true {
            try await writeLine("\(command) \(escape(file)) \(offset)")

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
