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

    case readUntilConditionNotMet
    case malformedResponse
    case wrongMode
}

actor ConnectionManager {
    static let shared = ConnectionManager(idle: true)

    private(set) var idle: Bool
    private(set) var connection: NWConnection?

    private var buffer = Data()
    // private let semaphore = DispatchSemaphore(value: 1)

    init(idle: Bool = false) {
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

        let lines = try await readUntilOK()
        guard lines.contains(where: { $0.hasPrefix("OK MPD") }) else {
            throw ConnectionManagerError.connectionError
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil

        buffer.removeAll()
    }

    func ensureConnectionReady() throws -> NWConnection {
        guard let connection, connection.state == .ready else {
            throw ConnectionManagerError.notConnected
        }

        return connection
    }

    func run(_ commands: [String]) async throws -> [String] {
        var commands = commands

        if commands.count > 1 {
            commands.insert("command_list_begin", at: 0)
            commands.append("command_list_end")
        }

        // TODO: Is this still needed?
        // await withCheckedContinuation { continuation in
        //     DispatchQueue.global().async {
        //         self.semaphore.wait()
        //         continuation.resume()
        //     }
        // }
        // defer { semaphore.signal() }

        try await writeLine(commands.joined(separator: "\n"))

        let lines = try await readUntilOKOrACK()
        if let ack = lines.first(where: { $0.hasPrefix("ACK") }) {
            throw ConnectionManagerError.protocolError(ack)
        }

        return lines
    }

    func idleForEvents(mask: [String]) async throws -> String {
        guard idle else {
            throw ConnectionManagerError.wrongMode
        }

        let lines = try await run(["idle \(mask.joined(separator: " "))"])
        guard let changedLine = lines.first(where: { $0.hasPrefix("changed: ") }) else {
            throw ConnectionManagerError.protocolError("No changed line")
        }

        return String(changedLine.dropFirst("changed: ".count))
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

    private func readLine() async throws -> String? {
        if let line = try? extractLineFromBuffer() {
            return line
        }

        try await receiveDataChunk()

        return try extractLineFromBuffer()
    }

    private func readFixedLengthData(_ length: Int) async throws -> Data {
        var data = Data()

        while data.count < length {
            if buffer.isEmpty {
                try await receiveDataChunk()
            }

            let needed = length - data.count
            let chunk = buffer.prefix(needed)

            data.append(chunk)
            buffer.removeFirst(chunk.count)
        }

        return data
    }

    private func extractLineFromBuffer() throws -> String? {
        guard let range = buffer.firstRange(of: Data([0x0A])) else {
            return nil
        }

        let data = buffer[..<range.lowerBound]
        buffer.removeSubrange(buffer.startIndex ..< range.upperBound)

        guard let string = String(data: data, encoding: .utf8) else {
            throw ConnectionManagerError.malformedResponse
        }

        return string.trimmingCharacters(in: .newlines)
    }

    private func receiveDataChunk() async throws {
        let connection = try ensureConnectionReady()

        guard let chunk = try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Data?, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if isComplete {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }) else {
            throw ConnectionManagerError.connectionClosed
        }

        buffer.append(chunk)
    }

    private func readUntil(_ condition: @escaping (String) -> Bool) async throws -> [String] {
        var lines: [String] = []

        while let line = try await readLine() {
            lines.append(line)

            if condition(line) {
                return lines
            }
        }

        throw ConnectionManagerError.readUntilConditionNotMet
    }

    private func readUntilOK() async throws -> [String] {
        try await readUntil { $0.hasPrefix("OK") }
    }

    private func readUntilOKOrACK() async throws -> [String] {
        try await readUntil { $0.hasPrefix("OK") || $0.hasPrefix("ACK") }
    }

    // MARK: - Parsing

    private func parseLine(_ line: String) throws -> (String, String) {
        let parts = line.split(separator: ":", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        guard parts.count == 2 else {
            throw ConnectionManagerError.malformedResponse
        }

        return (parts[0].lowercased(), parts[1])
    }

    private func parseMediaResponse(_ lines: [String], using media: MediaType) throws -> (any Mediable)? {
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

            let (key, value) = try parseLine(line)

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

    // MARK: - Command API

    func getStatusData() async throws -> (state: PlayerState?, isRandom: Bool?, isRepeat: Bool?, elapsed: Double?, song: Song?) {
        guard idle else {
            throw ConnectionManagerError.wrongMode
        }

        let lines = try await run(["status"])

        var state: PlayerState?
        var isRandom: Bool?
        var isRepeat: Bool?
        var elapsed: Double?
        var song: Song?

        for line in lines {
            guard line != "OK" else {
                break
            }

            let (key, value) = try parseLine(line)

            switch key {
            case "state":
                state = switch value {
                case "play":
                    .play
                case "pause":
                    .pause
                case "stop":
                    .stop
                default:
                    throw ConnectionManagerError.malformedResponse
                }
            case "random":
                isRandom = (value == "1")
            case "repeat":
                isRepeat = (value == "1")
            case "elapsed":
                elapsed = Double(value)
            case "playlist":
                print("TODO")
            case "songid":
                let lines = try await run(["playlistid \(value)"])

                song = try parseMediaResponse(lines, using: .song) as? Song
            default:
                break
            }
        }

        return (state, isRandom, isRepeat, elapsed, song)
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
            // TODO: Probably doesn't work with two albums with the same name.
            try await run(["playlistfind \(filter(key: "album", value: album.title, comparator: "=="))"])
        default:
            try await run(["playlistinfo"])
        }

        var chunks = [[String]]()
        var chunk = [String]()
                
        for line in lines {
            if line.hasPrefix("file"), !chunk.isEmpty {
                chunks.append(chunk)
                chunk.removeAll(keepingCapacity: true)
            }
            
            chunk.append(line)
        }
        
        return try chunks.map { chunk in
            try parseMediaResponse(chunk, using: .song) as! Song
        }
    }

    func getAlbums() async throws -> [Album] {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        let lines = try await run(["playlistfind \"(\(filter(key: "track", value: "1", comparator: "==", quote: false)) AND \(filter(key: "disc", value: "1", comparator: "==", quote: false)))\""])

        var chunks = [[String]]()
        var chunk = [String]()

        for line in lines {
            if line.hasPrefix("file"), !chunk.isEmpty {
                chunks.append(chunk)
                chunk.removeAll(keepingCapacity: true)
            }
            
            chunk.append(line)
        }

        return try chunks.map { chunk in
            try parseMediaResponse(chunk, using: .album) as! Album
        }
    }

    func getArtworkData(for uri: URL) async throws -> Data {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        var data = Data()
        var offset = 0
        var totalSize: Int?

        while true {
            try await writeLine("readpicture \"\(uri.path)\" \(offset)")

            var chunkSize: Int?

            while chunkSize == nil {
                guard let line = try? await readLine() else {
                    throw ConnectionManagerError.malformedResponse
                }

                if line.hasPrefix("OK") {
                    break
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
                throw ConnectionManagerError.malformedResponse
            }

            let binaryChunk = try await readFixedLengthData(chunkSize)
            data.append(binaryChunk)
            buffer.removeAll()

            offset += chunkSize

            if offset >= (totalSize ?? 0) {
                return data
            }
        }
    }

    func play(_ media: any Mediable) async throws {
        guard !idle else {
            throw ConnectionManagerError.wrongMode
        }

        try await connect()
        defer { disconnect() }

        print(media.id)

        _ = try await run(["playid \(media.id)"])
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
}

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
//    func createPlaylist(named name: String) throws {
//        try connect()
//        defer { disconnect() }
//
//        mpd_run_save(connection, name)
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
