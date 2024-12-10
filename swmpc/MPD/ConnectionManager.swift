//
//  ConnectionManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import Network
import OrderedCollections
import SwiftUI

enum ConnectionManagerError: Error {
    case connectionError
    case notConnected
    case connectionClosed

    case protocolError(String)

    case wrongMode
}

actor ConnectionManager {
    static let idle = ConnectionManager(idle: true)
    static let command = ConnectionManager(idle: false)

    private(set) var idle: Bool
    private(set) var connection: NWConnection?

    private init(idle: Bool) {
        self.idle = idle
    }

    // MARK: - Connection API

    func connect() async throws {
        guard connection == nil else {
            return
        }

        connection = NWConnection(host: NWEndpoint.Host("localhost"), port: NWEndpoint.Port(rawValue: 6600)!, using: .tcp)
        guard let connection else {
            throw ConnectionManagerError.connectionError
        }

        connection.start(queue: .global())
        try await waitForConnectionReady()

        var buffer = Data()
        let lines = try await readUntilOK(&buffer)
        guard lines.contains(where: { $0.hasPrefix("OK MPD") }) else {
            throw ConnectionManagerError.connectionError
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    func run(_ commands: [String]) async throws -> [String] {
        var commands = commands

        if commands.count > 1 {
            commands.insert("command_list_begin", at: 0)
            commands.append("command_list_end")
        }

        try await writeLine(commands.joined(separator: "\n"))

        var buffer = Data()
        let lines = try await readUntilOKOrACK(&buffer)
        if let ackLine = lines.first(where: { $0.hasPrefix("ACK") }) {
            throw ConnectionManagerError.protocolError(ackLine)
        }

        return lines
    }

    func idleForEvents(mask: [String]) async throws -> String {
        guard idle else {
            throw ConnectionManagerError.wrongMode
        }

        let lines = try await run(["idle \(mask.joined(separator: " "))"])

        return String((lines.first! as String).dropFirst(9))
    }

    // MARK: - Connection lifecycle

    private func waitForConnectionReady() async throws {
        guard let connection else {
            throw ConnectionManagerError.connectionError
        }

        let states = AsyncStream<NWConnection.State> { continuation in
            connection.stateUpdateHandler = { state in
                continuation.yield(state)

                if case .cancelled = state {
                    continuation.finish()
                }
            }
        }

        for await state in states {
            switch state {
            case .ready:
                return
            case let .failed(error):
                throw error
            case .cancelled:
                throw ConnectionManagerError.connectionClosed
            default:
                continue
            }
        }

        throw ConnectionManagerError.connectionError
    }

    private func ensureConnectionReady() throws -> NWConnection {
        guard let connection, connection.state == .ready else {
            throw ConnectionManagerError.notConnected
        }

        return connection
    }

    // MARK: - Writing

    private func writeLine(_ line: String) async throws {
        let connection = try ensureConnectionReady()

        let data = (line.appending("\n")).data(using: .utf8)!

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func filter(key: String, value: String, comparator: String, quote: Bool = true) -> String {
        let escapedValue = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\\\'")
            .replacingOccurrences(of: "\"", with: "\\\\\\\"")

        let clause = "(\(key) \(comparator) '\(escapedValue)')"

        return quote ? "\"\(clause)\"" : clause
    }

    // MARK: - Reading

    private func readLine(_ buffer: inout Data) async throws -> String? {
        if let line = extractLineFromBuffer(&buffer) {
            return line
        }

        let connection = try ensureConnectionReady()

        guard let chunk = try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Data?, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if isComplete || data == nil {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }) else {
            return nil
        }

        buffer.append(chunk)
        return extractLineFromBuffer(&buffer)
    }

    private func extractLineFromBuffer(_ buffer: inout Data) -> String? {
        guard let newlineRange = buffer.firstRange(of: Data([0x0A])) else {
            return nil
        }

        let lineData = buffer[..<newlineRange.lowerBound]
        let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .newlines)

        buffer.removeSubrange(buffer.startIndex ..< newlineRange.upperBound)

        return line
    }

    private func readUntil(_ buffer: inout Data, _ condition: @escaping (String) -> Bool) async throws -> [String] {
        var lines: [String] = []

        while let line = try await readLine(&buffer) {
            lines.append(line)
            log(severity: "LINE", line)

            if condition(line) {
                return lines
            }
        }

        print(lines)
        throw ConnectionManagerError.connectionClosed
    }

    private func readUntilOK(_ buffer: inout Data) async throws -> [String] {
        try await readUntil(&buffer) { $0.hasPrefix("OK") }
    }

    private func readUntilOKOrACK(_ buffer: inout Data) async throws -> [String] {
        try await readUntil(&buffer) { $0.hasPrefix("OK") || $0.hasPrefix("ACK") }
    }

    // MARK: - Parsing

    private func parseMediaResponse(_ lines: [String], using media: MediaType) -> (any Mediable)? {
        var id: UInt32 = 0
        var uri: URL?
        var artist: String?
        var album: String?
        var title: String?
        var track: Int?
        var date: String?
        var disc: Int?
        var albumArtist: String?
        var duration: Double = 0

        for line in lines {
            guard line != "OK" else {
                break
            }

            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else {
                continue
            }

            let key = parts[0].lowercased()
            let value = parts[1]

            switch key {
            case "id":
                id = UInt32(value) ?? 0
            case "file":
                uri = URL(string: value)
            case "artist":
                artist = value
            case "album":
                album = value
            case "title":
                title = value
            case "track":
                track = Int(value)
            case "date":
                date = value
            case "disc":
                disc = Int(value)
            case "albumartist":
                albumArtist = value
            case "duration":
                duration = Double(value) ?? 0
            default:
                break
            }
        }

        switch media {
        case .album:
            return Album(
                id: id,
                uri: uri ?? URL(string: "unknown:///")!,
                artist: albumArtist ?? "Unknown Artist",
                title: album ?? "Unknown Title",
                date: date ?? "1970"
            )
        default:
            return Song(
                id: id,
                uri: uri ?? URL(string: "unknown:///")!,
                artist: artist ?? "Unknown Artist",
                title: title ?? "Unknown Title",
                duration: duration,
                disc: disc ?? 1,
                track: track ?? 1
            )
        }
    }

    private func parseBinaryResponse(_ lines: [String]) -> Data? {
        var totalSize: Int?
        var binaryChunkSize: Int?

        // We're not returning until "OK" or "ACK" is encountered, so let's parse metadata first.
        for line in lines {
            let trimmedLine = line.trimmed()
            guard trimmedLine != "OK" else {
                // We've reached the end of this particular response.
                // If we never got binary data, return nil.
                return nil
            }

            // Split key/value pairs
            let parts = trimmedLine.split(separator: ":", maxSplits: 1).map { String($0).trimmed() }
            guard parts.count == 2 else { continue }

            let key = parts[0].lowercased()
            let value = parts[1]

            switch key {
            case "size":
                totalSize = Int(value)
            case "binary":
                binaryChunkSize = Int(value)
            default:
                break
            }
        }

        // If there's a binary chunk expected, read it now
        if let chunkSize = binaryChunkSize, chunkSize > 0 {
            // Reserve capacity if total size is known
            var binaryData = Data()
            binaryData.reserveCapacity(totalSize ?? chunkSize)

            // At this point, we must read exactly `chunkSize` bytes of binary data from the connection
            // after the textual lines have been read.
            let connection = try ensureConnectionReady()
            let receivedData = try await readExactBytes(count: chunkSize, from: connection, buffer: &buffer)
            binaryData.append(receivedData)
            return binaryData
        }

        // No binary data
        return nil
    }

    // MARK: - Command API

    func getCurrentSong() async throws -> Song? {
        guard idle else {
            throw ConnectionManagerError.wrongMode
        }

        let lines = try await run(["currentsong"])

        return parseMediaResponse(lines, using: .song) as? Song
    }

    func getStatusData() async throws -> (isPlaying: Bool?, isRandom: Bool?, isRepeat: Bool?, elapsed: Double?) {
        guard idle else {
            throw ConnectionManagerError.wrongMode
        }

        let lines = try await run(["status"])

        var isPlaying: Bool?
        var isRandom: Bool?
        var isRepeat: Bool?
        var elapsed: Double?

        for line in lines {
            guard line != "OK" else {
                break
            }

            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else {
                continue
            }

            let key = parts[0].lowercased()
            let value = parts[1]

            switch key {
            case "state":
                isPlaying = (value == "play")
            case "random":
                isRandom = (value == "1")
            case "repeat":
                isRepeat = (value == "1")
            case "elapsed":
                elapsed = Double(value)
            default:
                break
            }
        }

        return (isPlaying, isRandom, isRepeat, elapsed)
    }

    func loadPlaylist(_ playlist: Playlist?) async throws {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        if let playlist {
            _ = try await run(["clear", "load \(playlist.name)"])
        } else {
            _ = try await run(["clear", "add /"])
        }
    }

    func getSongs(for media: (any Mediable)? = nil) async throws -> [Song] {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        let lines: [String] = switch media {
        case let artist as Artist:
            try await run(["playlistfind \(filter(key: "albumArtist", value: artist.name, comparator: "=="))"])
        case let album as Album:
            try await run(["playlistfind \(filter(key: "artist", value: album.title, comparator: "=="))"])
        default:
            try await run(["playlistinfo"])
        }

        var songs = [Song]()
        var chunks = [[String]]()
        var chunk = [String]()

        for line in lines {
            if line.hasPrefix("Id"), !chunk.isEmpty {
                chunks.append(chunk)
                chunk = []
            }

            chunk.append(line)
        }

        for chunk in chunks {
            songs.append(parseMediaResponse(chunk, using: .song) as! Song)
        }

        return songs
    }

    func getAlbums() async throws -> [Album] {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        let lines = try await run(["playlistfind \"(\(filter(key: "track", value: "1", comparator: "==", quote: false)) AND \(filter(key: "disc", value: "1", comparator: "==", quote: false)))\""])

        var albums = [Album]()
        var chunks = [[String]]()
        var chunk = [String]()

        for line in lines {
            if line.hasPrefix("Id"), !chunk.isEmpty {
                chunks.append(chunk)
                chunk = []
            }

            chunk.append(line)
        }

        for chunk in chunks {
            albums.append(parseMediaResponse(chunk, using: .album) as! Album)
        }

        return albums
    }

    func getArtworkData(for uri: URL) async throws -> Data {
        try await connect()
        defer { disconnect() }

        // Start reading from offset 0. You can modify this logic to read in chunks if needed.
        var offset = 0
        var completeData = Data()

        // The protocol allows reading partial data. We can loop until we've fetched all.
        // For demonstration, we read the whole image in chunks until fully retrieved.
        while true {
            // Issue the readpicture command
            try await writeLine("readpicture \(uri.path) \(offset)")

            var buffer = Data()
            let lines = try await readUntilOKOrACK(&buffer)

            // Parse binary response (if any)
            guard let chunk = try await parseBinaryResponse(lines: lines, buffer: &buffer) else {
                // No binary data returned. If offset == 0 and no data, no artwork available.
                // Otherwise, we've retrieved all chunks.
                break
            }

            completeData.append(chunk)
            offset += chunk.count

            // If the chunk is smaller than some large chunk size (indicating we've got everything),
            // or no more binary lines returned, we can break.
            // Here we rely on `size:` to determine if we've reached the end.
            // If `size` was known, we could check if offset >= size and break.
            // For simplicity, assume that if we got a chunk smaller than the requested chunk size or no binary next time, we're done.
            if chunk.isEmpty {
                break
            }
        }

        return completeData
    }

    func pause(_ value: Bool) async throws {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        _ = try await run([value ? "pause 1" : "pause 0"])
    }

    func previous() async throws {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        _ = try await run(["previous"])
    }

    func next() async throws {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        _ = try await run(["next"])
    }

    func `repeat`(_ value: Bool) async throws {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        _ = try await run([value ? "repeat 1" : "repeat 0"])
    }

    func random(_ value: Bool) async throws {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        _ = try await run([value ? "random 1" : "random 0"])
    }

    func seek(_ value: Double) async throws {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        _ = try await run(["seekcur \(value)"])
    }

    private func log(severity: String, _ message: String) {
        if severity == "LINE" {
            return
        }

        print(severity + " " + (idle ? "IDLE" : "COMMAND") + ": " + message)
    }
}

// actor CommandManager: ConnectionManager {
//    private func run(_ action: (OpaquePointer) -> Void) throws {
//        try connect()
//        defer { disconnect() }
//
//        guard let connection else {
//            throw ConnectionManagerError.connectionError
//        }
//
//        action(connection)
//    }
//
//    func getElapsedData() throws -> Double? {
//        try connect()
//        defer { disconnect() }
//
//        guard let connection, let recv = mpd_run_status(connection) else {
//            return nil
//        }
//        defer { mpd_status_free(recv) }
//
//        return Double(mpd_status_get_elapsed_time(recv))
//    }
//

//
//    func createPlaylist(named name: String) throws {
//        try connect()
//        defer { disconnect() }
//
//        mpd_run_save(connection, name)
//    }
//
//    func loadPlaylist(_ playlist: Playlist?) throws {
//        try connect()
//        defer { disconnect() }
//
//        mpd_run_clear(connection)
//
//        if let playlist {
//            mpd_run_load(connection, playlist.name)
//        } else {
//            mpd_run_add(connection, "/")
//        }
//    }
//
//    func addToPlaylist(_ playlist: Playlist, songs: [Song]) throws {
//        try connect()
//        defer { disconnect() }
//
//        for song in songs {
//            mpd_run_playlist_add(connection, playlist.name, song.uri.path)
//        }
//    }
// }
