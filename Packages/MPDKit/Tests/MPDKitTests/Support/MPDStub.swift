//
//  MPDStub.swift
//  MPDKit
//
//  Created by Camille Scholtz on 01/09/2026.
//

import Foundation
import Synchronization

@testable import MPDKit

/// A stand-in for an MPD server.
///
/// It speaks enough of the wire protocol over a loopback socket for a real
/// `ConnectionManager` to be driven against it: it greets each connection,
/// records every request it is sent, and answers each one with the next
/// scripted reply. Requests are recorded verbatim, command list wrappers
/// included, so a test can assert on exactly what went over the wire.
///
/// Connections are served one at a time and in order, so an operation that
/// opens a fresh connection — everything that goes through
/// ``ConnectionManager/withConnection(_:)`` does — is answered from the same
/// script as the one before it.
final class MPDStub: Sendable {
    /// Why a stub could not be brought up. Only ever a local socket refusing
    /// to be created, bound, or listened on.
    enum StubError: Error {
        case socketUnavailable
    }

    /// The loopback port the stub is listening on.
    let port: Int

    private let descriptor: Int32
    private let parksIdle: Bool
    private let state = Mutex(State())
    private let finished = DispatchSemaphore(value: 0)

    /// What the stub has been told, and what it has left to say.
    private struct State {
        var requests: [[String]] = []
        var replies: [Data] = []
        var client: Int32?
        var isStopped = false
    }

    /// Brings up a stub on an unused loopback port.
    ///
    /// - Parameters:
    ///   - greeting: The line sent on connection, before any request.
    ///   - replies: One reply per request, in order. A request beyond the end
    ///              of the script is answered with a bare `OK`.
    ///   - parksIdle: Whether an `idle` is left waiting the way a real server
    ///                leaves it, to be answered only once `noidle` arrives.
    init(greeting: String = "OK MPD 0.24.0", replies: [Data] = [],
         parksIdle: Bool = false) throws
    {
        let descriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw StubError.socketUnavailable
        }

        var reuse: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &reuse,
                   socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        let isBound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0,
                     socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }

        guard isBound, listen(descriptor, 4) == 0 else {
            close(descriptor)

            throw StubError.socketUnavailable
        }

        var assigned = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let isNamed = withUnsafeMutablePointer(to: &assigned) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(descriptor, $0, &length) == 0
            }
        }

        guard isNamed else {
            close(descriptor)

            throw StubError.socketUnavailable
        }

        self.descriptor = descriptor
        self.parksIdle = parksIdle
        port = Int(UInt16(bigEndian: assigned.sin_port))

        state.withLock { $0.replies = replies }

        let line = Data("\(greeting)\n".utf8)
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            serve(greeting: line)
        }
    }

    /// Every request the stub has received, as the lines it was sent.
    var requests: [[String]] {
        state.withLock { $0.requests }
    }

    /// Every request with any command list wrapper stripped off.
    var commands: [[String]] {
        requests.map { lines in
            lines.filter {
                $0 != "command_list_begin" && $0 != "command_list_ok_begin"
                    && $0 != "command_list_end"
            }
        }
    }

    /// The commands of the last request, or nothing if none arrived.
    var lastCommands: [String] {
        commands.last ?? []
    }

    /// Hangs up on whoever is connected and stops listening, returning once
    /// the stub has let go of its socket.
    ///
    /// Only the thread that accepts may close the listening socket: closing
    /// it from here while that thread sits in `accept` would free the
    /// descriptor number for the next stub to be handed, leaving two stubs
    /// answering for one socket.
    func stop() {
        let client = state.withLock { state -> Int32? in
            state.isStopped = true

            return state.client
        }

        if let client {
            shutdown(client, SHUT_RDWR)
        }

        _ = finished.wait(timeout: .now() + .seconds(5))
    }

    // MARK: - Serving

    /// Serves connections one at a time until the stub is stopped.
    private func serve(greeting: Data) {
        while !state.withLock({ $0.isStopped }) {
            var pending = pollfd(fd: descriptor, events: Int16(POLLIN),
                                 revents: 0)

            guard poll(&pending, 1, 20) > 0 else {
                continue
            }

            let client = accept(descriptor, nil, nil)
            guard client >= 0 else {
                continue
            }

            var option: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &option,
                       socklen_t(MemoryLayout<Int32>.size))

            state.withLock { $0.client = client }

            converse(with: client, greeting: greeting)

            state.withLock { $0.client = nil }
            close(client)
        }

        close(descriptor)
        finished.signal()
    }

    /// Greets a client and answers its requests until it goes away.
    private func converse(with client: Int32, greeting: Data) {
        guard transmit(greeting, to: client) else {
            return
        }

        var buffer = [UInt8]()

        while let request = readRequest(from: client, into: &buffer) {
            let reply = state.withLock { state -> Data? in
                state.requests.append(request)

                if parksIdle, request.first?.hasPrefix("idle") == true {
                    return nil
                }

                guard !state.replies.isEmpty else {
                    return Self.reply()
                }

                return state.replies.removeFirst()
            }

            guard let reply else {
                continue
            }

            guard !reply.isEmpty, transmit(reply, to: client) else {
                return
            }
        }
    }

    /// Reads one request: a single command, or every line of a command list
    /// including the tokens that open and close it.
    private func readRequest(from client: Int32, into buffer: inout [UInt8])
        -> [String]?
    {
        var lines: [String] = []
        var isList = false

        while true {
            guard let line = readLine(from: client, into: &buffer) else {
                return nil
            }

            lines.append(line)

            switch line {
            case "command_list_begin", "command_list_ok_begin":
                isList = true
            case "command_list_end":
                return lines
            default:
                if !isList {
                    return lines
                }
            }
        }
    }

    /// Reads one newline-terminated line, refilling the buffer as needed.
    private func readLine(from client: Int32, into buffer: inout [UInt8])
        -> String?
    {
        while true {
            if let index = buffer.firstIndex(of: 0x0A) {
                let line = String(decoding: buffer[..<index], as: UTF8.self)
                buffer.removeFirst(index + 1)

                return line
            }

            var chunk = [UInt8](repeating: 0, count: 4096)
            let count = recv(client, &chunk, chunk.count, 0)

            guard count > 0 else {
                return nil
            }

            buffer.append(contentsOf: chunk[..<count])
        }
    }

    /// Writes every byte of `data`, reporting whether the client is still
    /// listening.
    private func transmit(_ data: Data, to client: Int32) -> Bool {
        data.withUnsafeBytes { raw -> Bool in
            guard let base = raw.baseAddress else {
                return true
            }

            var offset = 0
            while offset < raw.count {
                let written = send(client, base.advanced(by: offset),
                                   raw.count - offset, 0)

                guard written > 0 else {
                    return false
                }

                offset += written
            }

            return true
        }
    }
}

// MARK: - Scripted replies

extension MPDStub {
    /// A response carrying `lines`, terminated by the `OK` the protocol ends
    /// a successful command with.
    static func reply(_ lines: [String] = []) -> Data {
        Data((lines + ["OK"]).map { $0 + "\n" }.joined().utf8)
    }

    /// A failure, which the protocol spells
    /// `ACK [error@command_listNum] {current_command} message_text`.
    static func failure(code: Int = 50, index: Int = 0,
                        command: String = "albumart",
                        message: String = "No file exists") -> Data
    {
        Data("ACK [\(code)@\(index)] {\(command)} \(message)\n".utf8)
    }

    /// A binary response: the total size, an optional MIME type, the chunk
    /// length, the bytes themselves, and the newline the protocol puts
    /// between them and the closing `OK`.
    static func binary(_ payload: Data, size: Int? = nil,
                       type: String? = nil, file: String? = nil) -> Data
    {
        var header = ""
        if let file {
            header += "file: \(file)\n"
        }
        header += "size: \(size ?? payload.count)\n"
        if let type {
            header += "type: \(type)\n"
        }
        header += "binary: \(payload.count)\n"

        var data = Data(header.utf8)
        data.append(payload)
        data.append(0x0A)
        data.append(Data("OK\n".utf8))

        return data
    }

    /// A reply that hangs up instead of answering.
    static let hangUp = Data()

    /// A song as the server describes one, `file` first as the protocol
    /// requires.
    static func song(_ file: String, title: String? = nil,
                     artist: String? = nil, album: String? = nil,
                     albumArtist: String? = nil, disc: Int? = nil,
                     track: Int? = nil, duration: Double? = nil,
                     position: Int? = nil, identifier: Int? = nil) -> [String]
    {
        var lines = ["file: \(file)"]

        if let title { lines.append("Title: \(title)") }
        if let artist { lines.append("Artist: \(artist)") }
        if let album { lines.append("Album: \(album)") }
        if let albumArtist { lines.append("AlbumArtist: \(albumArtist)") }
        if let disc { lines.append("Disc: \(disc)") }
        if let track { lines.append("Track: \(track)") }
        if let duration { lines.append("duration: \(duration)") }
        if let position { lines.append("Pos: \(position)") }
        if let identifier { lines.append("Id: \(identifier)") }

        return lines
    }

    /// The tag types a current server reports, as `tagtypes` lines.
    static func tagTypes(_ names: [String] = []) -> Data {
        reply(names.map { "tagtype: \($0)" })
    }

    /// Runs `body` against a stub the connection configuration points at,
    /// putting the configuration back afterwards.
    ///
    /// The stub replaces the selected server, which also drops any tag list
    /// cached from an earlier one, so each test starts from a server that has
    /// not been asked anything yet.
    static func withServer(
        greeting: String = "OK MPD 0.24.0",
        replies: [Data] = [],
        password: String = "",
        artworkGetter: ArtworkGetter = .libraryThenMetadata,
        parksIdle: Bool = false,
        _ body: (MPDStub) async throws -> Void,
    ) async throws {
        let stub = try MPDStub(greeting: greeting, replies: replies,
                               parksIdle: parksIdle)

        defer {
            ConnectionConfiguration.server = nil
            stub.stop()
        }

        ConnectionConfiguration.server = Server(
            host: "127.0.0.1", port: stub.port, password: password,
            artworkGetter: artworkGetter,
        )

        try await body(stub)
    }
}
