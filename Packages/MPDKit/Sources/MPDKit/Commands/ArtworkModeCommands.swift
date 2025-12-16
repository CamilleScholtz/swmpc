//
//  ArtworkModeCommands.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import Foundation

/// Commands specific to artwork mode connections.
public extension ConnectionManager where Mode == ArtworkMode {
    /// Executes an artwork operation with automatic connection cleanup.
    ///
    /// This method creates a new connection, executes the provided closure with
    /// the connection manager, and ensures the connection is properly
    /// disconnected when the operation completes (whether it succeeds or
    /// throws).
    ///
    /// - Parameter operation: A closure that receives a connected
    ///                        `ConnectionManager<ArtworkMode>` and performs
    ///                        operations on it.
    /// - Returns: The result of the operation closure.
    /// - Throws: An error if the connection fails or if the operation throws.
    static func artwork<T: Sendable>(_ operation: @Sendable (
        ConnectionManager<ArtworkMode>) async throws -> T) async throws -> T
    {
        let manager = ConnectionManager<ArtworkMode>()
        try await manager.connect()

        do {
            let result = try await operation(manager)
            await manager.disconnect()

            return result
        } catch {
            await manager.disconnect()

            throw error
        }
    }

    /// Retrieves the complete artwork data for a given file by fetching it in
    /// chunks from the media server.
    ///
    /// This method uses optimized receive calls to efficiently fetch artwork
    /// data, taking advantage of the ArtworkMode's larger buffer size for
    /// improved performance when transferring image data.
    ///
    /// - Parameter file: The file path representing the artwork resource on
    ///                   the server.
    /// - Returns: A `Data` object containing the complete binary artwork data.
    /// - Throws: An error if the server response is malformed, if the read
    ///           operation fails, or if other connection related errors occur.
    func getArtworkData(for file: String) async throws -> Data {
        var data = Data()
        var offset = 0
        var totalSize: Int?

        loop: while true {
            let artworkGetter = ConnectionConfiguration.server?.artworkGetter ?? .library
            try await writeLine("\(artworkGetter.rawValue) \(escape(file)) \(offset)")

            var chunkSize: Int?

            while chunkSize == nil {
                guard let line = try await readLine() else {
                    continue
                }

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
                    "Missing chunk size")
            }

            let binaryChunk = try await readFixedLengthData(chunkSize)
            data.append(binaryChunk)

            while let line = try await readLine() {
                if line.hasPrefix("OK") {
                    offset += chunkSize

                    if offset >= (totalSize ?? 0) {
                        return data
                    } else {
                        continue loop
                    }
                }
            }

            throw ConnectionManagerError.malformedResponse("Missing 'OK' line")
        }
    }
}
