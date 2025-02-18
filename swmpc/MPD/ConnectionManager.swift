//
//  ConnectionManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import Network
import SwiftUI

protocol ConnectionMode {
    static var enableKeepalive: Bool { get }
    static var bufferSize: Int { get }
}

enum IdleMode: ConnectionMode {
    static let enableKeepalive = true
    static let bufferSize = 4096
}

enum ArtworkMode: ConnectionMode {
    static let enableKeepalive = true
    static let bufferSize = 16384
}

enum CommandMode: ConnectionMode {
    static let enableKeepalive = false
    static let bufferSize = 4096
}

enum ConnectionManagerError: Error {
    case connectionError
    case connectionClosed

    case protocolError(String)

    case readUntilConditionNotMet
    case malformedResponse
}

struct ConnectionManagerConfig {
    static let shared = ConnectionManagerConfig()

    let host: String
    let port: UInt16

    private init() {
        let defaults = UserDefaults.standard

        host = defaults.string(forKey: "host") ?? "localhost"
        port = UInt16(defaults.integer(forKey: "port"))
    }
}

actor ConnectionManager<Mode: ConnectionMode> {
    private let host = ConnectionManagerConfig.shared.host
    private let port = ConnectionManagerConfig.shared.port

    private var connection: NWConnection?
    private var buffer = Data()
    private let connectionQueue = DispatchQueue(label: "com.swmpc.connection")

    private init() {}

    // TODO: I want to just use `disconnect()` here, but that gives me an `Call to actor-isolated instance method 'disconnect()' in a synchronous nonisolated context` error.
    deinit {
        connection?.cancel()
        connection = nil

        buffer.removeAll()
    }

    func connect() async throws {
        guard connection?.state != .ready else {
            return
        }

        let options = NWProtocolTCP.Options()
        options.noDelay = true
        options.enableKeepalive = Mode.enableKeepalive

        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: NWParameters(tls: nil, tcp: options)
        )
        guard let connection else {
            throw ConnectionManagerError.connectionError
        }

        connection.start(queue: connectionQueue)
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
            throw ConnectionManagerError.connectionClosed
        }

        return connection
    }

    func run(_ commands: [String]) async throws -> [String] {
        var list = commands

        if list.count > 1 {
            list.insert("command_list_begin", at: 0)
            list.append("command_list_end")
        }

        try await writeLine(list.joined(separator: "\n"))

        return try await readUntilOK()
    }

    // MARK: - Connection lifecycle

    private func waitForConnectionReady() async throws {
        guard let connection else {
            throw ConnectionManagerError.connectionError
        }

        let states = AsyncStream<NWConnection.State> { continuation in
            connection.stateUpdateHandler = { state in
                continuation.yield(state)

                switch state {
                case .cancelled, .failed, .ready:
                    continuation.finish()
                default:
                    break
                }
            }
        }

        for await state in states {
            switch state {
            case .ready:
                return
            case let .failed(error):
                disconnect()
                throw error
            case let .waiting(error):
                disconnect()
                throw error
            case .cancelled:
                disconnect()
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

        let data = (line + "\n").data(using: .utf8)!

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

    private func escape(_ string: String, quote: String? = "\"") -> String {
        var escaped = string.replacingOccurrences(of: "\\", with: "\\\\")

        guard let quote else {
            return escaped
        }

        switch quote {
        case "\"":
            escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        case "'":
            escaped = escaped.replacingOccurrences(of: "'", with: "\\'")
        default:
            break
        }

        return "\(quote)\(escaped)\(quote)"
    }

    private func filter(key: String, value: String, comparator: String, quote: Bool = true) -> String {
        let clause = "(\(key) \(comparator) \(escape(value, quote: "'")))"
            .replacingOccurrences(of: "\\", with: "\\\\")

        return quote ? "\"\(clause)\"" : clause
    }

    // MARK: - Reading

    private func readLine() async throws -> String? {
        while true {
            if let line = try extractLineFromBuffer() {
                if line.hasPrefix("ACK") {
                    throw ConnectionManagerError.protocolError(line)
                }

                return line
            }

            try await receiveDataChunk()
        }
    }

    private func readFixedLengthData(_ length: Int) async throws -> Data {
        var data = Data()
        data.reserveCapacity(length)

        var remaining = length

        while remaining > 0 {
            if buffer.isEmpty {
                try await receiveDataChunk()
            }

            let chunkCount = min(buffer.count, remaining)

            data.append(buffer.prefix(chunkCount))
            buffer.removeFirst(chunkCount)

            remaining -= chunkCount
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

        return string
    }

    private func receiveDataChunk() async throws {
        let connection = try ensureConnectionReady()

        guard let chunk = try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Data?, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: Mode.bufferSize) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: data)
                }
            }
        }) else {
            throw ConnectionManagerError.connectionClosed
        }

        buffer.append(chunk)
    }

    private func chunkLines(_ lines: [String], startingWith prefix: String) -> [[String]] {
        var chunks = [[String]]()
        var currentChunk = [String]()

        for line in lines {
            if line.hasPrefix(prefix), !currentChunk.isEmpty {
                chunks.append(currentChunk)
                currentChunk.removeAll()
            }

            currentChunk.append(line)
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks
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
        var id: UInt32?
        var position: UInt32?
        var url: URL?
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
            case "pos":
                position = UInt32(value)
            case "file":
                guard let formatted = URL(string: value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "") else {
                    throw ConnectionManagerError.malformedResponse
                }

                url = formatted
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

        guard let url else {
            throw ConnectionManagerError.malformedResponse
        }

        switch media {
        case .album:
            return Album(
                id: id ?? 0,
                position: position ?? 0,
                url: url,
                artist: albumArtist ?? "Unknown Artist",
                title: album ?? "Unknown Title",
                date: date ?? "1970"
            )
        default:
            return Song(
                id: id ?? 0,
                position: position ?? 0,
                url: url,
                artist: artist ?? "Unknown Artist",
                title: title ?? "Unknown Title",
                duration: duration,
                disc: disc ?? 1,
                track: track ?? 1
            )
        }
    }
}

// MARK: - Shared commands

extension ConnectionManager {
    func getStatusData() async throws -> (state: PlayerState?, isRandom: Bool?, isRepeat: Bool?, elapsed: Double?, song: Song?) {
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
            case "songid":
                let lines = try await run(["playlistid \(value)"])

                song = try parseMediaResponse(lines, using: .song) as? Song
            default:
                break
            }
        }

        return (state, isRandom, isRepeat, elapsed, song)
    }

    func getSongs(for media: (any Mediable)? = nil) async throws -> [Song] {
        let lines: [String] = switch media {
        case let artist as Artist:
            try await run(["playlistfind \(filter(key: "albumArtist", value: artist.name, comparator: "=="))"])
        case let album as Album:
            // TODO: Probably doesn't work with two albums with the same name.
            try await run(["playlistfind \(filter(key: "album", value: album.title, comparator: "=="))"])
        default:
            try await run(["playlistinfo"])
        }

        let chunks = chunkLines(lines, startingWith: "file")

        return try chunks.map { chunk in
            try parseMediaResponse(chunk, using: .song) as! Song
        }
    }

    func getAlbums() async throws -> [Album] {
        let lines = try await run(["playlistfind \"(\(filter(key: "track", value: "1", comparator: "==", quote: false)) AND \(filter(key: "disc", value: "1", comparator: "==", quote: false)))\""])
        let chunks = chunkLines(lines, startingWith: "file")

        return try chunks.map { chunk in
            try parseMediaResponse(chunk, using: .album) as! Album
        }
    }

    func getPlaylists() async throws -> [Playlist] {
        let lines = try await run(["listplaylists"])
        var index: UInt32 = 0
        var playlists = [Playlist]()

        for line in lines {
            guard line != "OK" else {
                break
            }

            let (key, value) = try parseLine(line)

            if key == "playlist" {
                playlists.append(Playlist(
                    id: index,
                    position: index,
                    name: value
                ))

                index += 1
            }
        }

        return playlists
    }

    func getPlaylist(_ playlist: Playlist) async throws -> [Song] {
        let lines = try await run(["listplaylistinfo \(playlist.name)"])
        let chunks = chunkLines(lines, startingWith: "file")

        return try chunks.enumerated().map { index, chunk in
            let song = try parseMediaResponse(chunk, using: .song) as! Song

            return Song(
                id: UInt32(index),
                position: UInt32(index),
                url: song.url,
                artist: song.artist,
                title: song.title,
                duration: song.duration,
                disc: song.disc,
                track: song.track
            )
        }
    }
}

// MARK: - Idle mode commands

extension ConnectionManager where Mode == IdleMode {
    static let idle = ConnectionManager<IdleMode>()

    func idleForEvents(mask: [IdleEvent]) async throws -> IdleEvent {
        let lines = try await run(["idle \(mask.map(\.rawValue).joined(separator: " "))"])
        guard let changedLine = lines.first(where: { $0.hasPrefix("changed: ") }) else {
            throw ConnectionManagerError.protocolError("No changed line")
        }

        return IdleEvent(rawValue: String(changedLine.dropFirst("changed: ".count)))!
    }
}

// MARK: - Artwork mode commands

extension ConnectionManager where Mode == ArtworkMode {
    static func artwork() async throws -> ConnectionManager<ArtworkMode> {
        let manager = ConnectionManager<ArtworkMode>()
        try await manager.connect()

        return manager
    }
    
    func getArtworkData(for url: URL) async throws -> Data {
        var data = Data()
        var offset = 0
        var totalSize: Int?

        while true {
            try await writeLine("readpicture \(escape(url.path)) \(offset)")

            var chunkSize: Int?

            while chunkSize == nil {
                guard let line = try await readLine() else {
                    continue
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
}

// MARK: - Command mode commands

extension ConnectionManager where Mode == CommandMode {
    static func command() async throws -> ConnectionManager<CommandMode> {
        let manager = ConnectionManager<CommandMode>()
        try await manager.connect()

        return manager
    }

    func loadPlaylist(_ playlist: Playlist?) async throws {
        if let playlist {
            _ = try await run(["clear", "load \(playlist.name)"])
        } else {
            _ = try await run(["clear", "add /"])
        }
    }

    func createPlaylist(named name: String) async throws {
        _ = try await run(["save \(name)", "playlistclear \(name)"])
    }

    func removePlaylist(_ playlist: Playlist) async throws {
        _ = try await run(["rm \(playlist.name)"])
    }

    func addToPlaylist(_ playlist: Playlist, songs: [Song]) async throws {
        let existingSongs = try await getPlaylist(playlist)
        let newSongs = songs.filter { song in
            !existingSongs.contains { $0.url == song.url }
        }

        let commands = newSongs.map {
            "playlistadd \(playlist.name) \(escape($0.url.path))"
        }

        _ = try await run(commands)
    }

    func removeFromPlaylist(_ playlist: Playlist, songs: [Song]) async throws {
        let commands = songs.map {
            "playlistdelete \(playlist.name) \($0.position)"
        }

        _ = try await run(commands)
    }

    func addToFavorites(songs: [Song]) async throws {
        try await addToPlaylist(Playlist(id: 0, position: 0, name: "Favorites"), songs: songs)
    }

    // TODO: Figure out how the positions works here
    func removeFromFavorites(songs: [Song]) async throws {
        try await removeFromPlaylist(Playlist(id: 0, position: 0, name: "Favorites"), songs: songs)
    }

    func update() async throws {
        _ = try await run(["update"])
    }

    func play(_ media: any Mediable) async throws {
        _ = try await run(["playid \(media.id)"])
    }

    func pause(_ value: Bool) async throws {
        _ = try await run([value ? "pause 1" : "pause 0"])
    }

    func previous() async throws {
        _ = try await run(["previous"])
    }

    func next() async throws {
        _ = try await run(["next"])
    }

    func `repeat`(_ value: Bool) async throws {
        _ = try await run([value ? "repeat 1" : "repeat 0"])
    }

    func random(_ value: Bool) async throws {
        _ = try await run([value ? "random 1" : "random 0"])
    }

    func seek(_ value: Double) async throws {
        _ = try await run(["seekcur \(value)"])
    }
}
