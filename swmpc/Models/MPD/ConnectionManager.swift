//
//  ConnectionManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import DequeModule
import KeychainStorageKit
import Network
import SwiftUI

/// Protocol defining the configuration for different connection modes to the
/// MPD server. Each mode can have different performance characteristics and
/// buffer sizes.
protocol ConnectionMode: Sendable {
    /// A label identifying the connection mode.
    static var label: String { get }
    /// Whether to enable TCP keepalive for this connection.
    static var enableKeepalive: Bool { get }
    /// The buffer size to use for reading data.
    static var bufferSize: Int { get }
    /// The dispatch queue attributes for this connection mode.
    static var queueAttributes: DispatchQueue.Attributes { get }
    /// The quality of service level for operations.
    static var qos: DispatchQoS { get }
}

/// Connection mode for idle operations that listen for MPD server events.
/// Uses keepalive to maintain long-lived connections.
enum IdleMode: ConnectionMode {
    static let label = "idle"
    static let enableKeepalive = true
    static let bufferSize = 4096
    static let queueAttributes: DispatchQueue.Attributes = []
    static let qos: DispatchQoS = .userInteractive
}

/// Connection mode for artwork retrieval operations.
/// Uses larger buffers and concurrent queue for efficient image data transfer.
enum ArtworkMode: ConnectionMode {
    static let label = "artwork"
    static let enableKeepalive = false
    static let bufferSize = 8192
    static let queueAttributes: DispatchQueue.Attributes = .concurrent
    static let qos: DispatchQoS = .utility
}

/// Connection mode for executing MPD commands.
/// Optimized for quick command execution with higher priority.
enum CommandMode: ConnectionMode {
    static let label = "command"
    static let enableKeepalive = false
    static let bufferSize = 4096
    static let queueAttributes: DispatchQueue.Attributes = []
    static let qos: DispatchQoS = .userInitiated
}

/// Errors that can occur during MPD connection management.
enum ConnectionManagerError: LocalizedError {
    case invalidPort
    case unsupportedServerVersion

    case connectionSetupFailed
    case connectionUnexpectedClosure
    case connectionTimeout

    case readUntilConditionNotMet

    case protocolViolation(String)
    case malformedResponse(String)
    case unsupportedOperation(String)

    var errorDescription: String? {
        switch self {
        case .invalidPort:
            "Invalid port provided. Port must be between 1 and 65535."
        case .unsupportedServerVersion:
            "Unsupported MPD server version. Minimum required version is 0.24."
        case .connectionSetupFailed:
            "Failed to establish network connection to MPD server."
        case .connectionUnexpectedClosure:
            "Network connection was closed unexpectedly during operation."
        case .connectionTimeout:
            "Connection attempt timed out."
        case .readUntilConditionNotMet:
            "Failed to locate expected response termination sequence."
        case let .protocolViolation(details):
            "MPD protocol violation: \(details)"
        case let .malformedResponse(details):
            "Received malformed or unexpected response format from server: \(details)"
        case let .unsupportedOperation(details):
            "Unsupported operation attempted: \(details)"
        }
    }
}

/// Manages TCP connections to the MPD server with support for different
/// connection modes.
///
/// The connection manager is generic over a `ConnectionMode` which determines
/// the connection characteristics such as buffer size, quality of service, and
/// whether keepalive is enabled.
///
/// Features:
/// - Automatic connection management and reconnection
/// - Command batching for efficient communication
/// - Response parsing for various MPD data types
/// - Thread-safe operation using Swift actors
actor ConnectionManager<Mode: ConnectionMode> {
    @AppStorage(Setting.host) private var host = "localhost"
    @AppStorage(Setting.port) private var port = 6600

    @KeychainStorage(Setting.password) private var password: String?

    private var connection: NWConnection?
    private let connectionQueue = DispatchQueue(
        label: "com.camille.swmpc.connection.\(Mode.label)",
        qos: Mode.qos,
        attributes: Mode.queueAttributes,
        target: .global(qos: Mode.qos.qosClass)
    )

    private var buffer = Deque<UInt8>()

    /// The version of the MPD server.
    private(set) var version: String?

    // TODO: I want to just use `disconnect()` here, but that gives me an `Call
    // to actor-isolated instance method 'disconnect()' in a synchronous
    // nonisolated context` error. The existing approach is reasonable.
    deinit {
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil

        buffer.removeAll(keepingCapacity: false)
    }

    /// Establishes a TCP connection to the MPD server.
    ///
    /// This asynchronous function sets up a new network connection using
    /// `NWConnection` with TCP options configured for no-delay, and keepalive
    /// depending on the `ConnectionMode`. If a connection is already active
    /// (i.e. in the `.ready` state), the function returns immediately.
    ///
    /// - Throws: `ConnectionManagerError.invalidPort` if the port is
    ///           invalid, `ConnectionManagerError.connectionSetupFailed` if the
    ///           connection cannot be created, the connection fails to become
    ///           ready, or the expected server greeting is not received,
    ///           `ConnectionManagerError.unsupportedServerVersion` if the
    ///           server version is not supported.
    func connect() async throws {
        try ensureVersionSupported()
        guard connection?.state != .ready else {
            return
        }

        let options = NWProtocolTCP.Options()
        options.noDelay = true
        options.enableKeepalive = Mode.enableKeepalive

        guard let port = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw ConnectionManagerError.invalidPort
        }

        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: port,
            using: NWParameters(tls: nil, tcp: options)
        )
        guard let connection else {
            throw ConnectionManagerError.connectionSetupFailed
        }

        connection.start(queue: connectionQueue)
        do {
            try await waitForConnectionReady()
        } catch {
            disconnect()
            throw error
        }

        let lines = try await readUntilOK()
        guard lines.contains(where: { $0.hasPrefix("OK MPD") }) else {
            throw ConnectionManagerError.connectionSetupFailed
        }

        version = lines.first?.split(separator: " ").last.map(String.init)
        try ensureVersionSupported()
        try await ensureAuthenticated()
    }

    /// Disconnects from the current network connection and clears internal
    /// data.
    ///
    /// Cancels any active connection, sets the connection to `nil`, and removes
    /// all buffered data. This method should be called to cleanly terminate the
    /// connection and reset the internal state.
    func disconnect() {
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil

        buffer.removeAll(keepingCapacity: false)

        version = nil
    }

    /// Ensures that the current network connection is available and ready.
    ///
    /// This function checks if there is an active `NWConnection` that is in the
    /// `.ready` state. If the connection is valid and ready, it returns the
    /// connection for use. Otherwise, it throws a
    /// `ConnectionManagerError.connectionUnexpectedClosure` error indicating
    /// that the connection is either not established or not ready.
    ///
    /// - Throws: `ConnectionManagerError.connectionUnexpectedClosure` if there
    ///           is no active connection or if the connection is not ready.
    /// - Returns: A ready-to-use `NWConnection` instance.
    func ensureConnectionReady() throws -> NWConnection {
        guard let connection, connection.state == .ready else {
            throw ConnectionManagerError.connectionUnexpectedClosure
        }

        return connection
    }

    /// Ensures that the server version is supported.
    ///
    /// This function checks the version of the MPD server and throws an error
    /// if the version is not supported. The minimum supported version is 0.24.
    ///
    /// - Throws: `ConnectionManagerError.unsupportedServerVersion` if the
    ///           server version is not supported.
    func ensureVersionSupported() throws {
        guard version?.compare("0.24", options: .numeric) !=
            .orderedAscending
        else {
            throw ConnectionManagerError.unsupportedServerVersion
        }
    }

    /// Ensures that the client is authenticated with the server.
    ///
    /// This function checks if a password is set and sends it to the server for
    /// authentication. If no password is set, the function returns immediately.
    func ensureAuthenticated() async throws {
        guard let password else {
            return
        }

        _ = try await run(["password", password])
    }

    /// Sends a ping command to the server.
    func ping() async throws {
        _ = try await run(["ping"])
    }

    /// Executes one or more commands asynchronously over the connection.
    ///
    /// If multiple commands are provided, the commands are wrapped within
    /// `command_list_begin` and `command_list_end` tokens to form a command
    /// list. The commands are concatenated using newline separators and sent
    /// over the connection. The function then awaits a response that concludes
    /// with an `OK` message.
    ///
    /// - Parameter commands: An array of command strings to execute.
    /// - Returns: An array of response lines returned by the server.
    /// - Throws: An error if writing to the connection or reading the response
    ///           fails.
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

    /// Asynchronously waits for the connection to be ready.
    ///
    /// This function uses a task group to monitor the connection state and
    /// handle timeouts. It listens for the connection state updates and checks
    /// if the connection is ready. If the connection fails or is cancelled,
    /// appropriate errors are thrown. The function also includes a timeout
    /// mechanism that throws a `ConnectionManagerError.connectionTimeout` error
    /// if the connection does not become ready within a specified duration.
    ///
    /// - Throws: `ConnectionManagerError.connectionUnexpectedClosure` if the
    ///           connection is closed unexpectedly, `ConnectionManagerError`
    ///           `connectionTimeout` if the connection does not become ready
    ///           within the specified duration, or any other error encountered
    ///           during the connection state updates.
    private func waitForConnectionReady() async throws {
        guard let connection else {
            throw ConnectionManagerError.connectionUnexpectedClosure
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self, connection] in
                guard self != nil else {
                    throw CancellationError()
                }

                let states = AsyncStream<NWConnection.State> { continuation in
                    connection.stateUpdateHandler = { state in
                        continuation.yield(state)
                        switch state {
                        case .ready, .failed, .cancelled:
                            continuation.finish()
                        default:
                            break
                        }
                    }
                }

                for await state in states {
                    try Task.checkCancellation()

                    switch state {
                    case .ready:
                        return
                    case let .failed(error):
                        throw error
                    case .cancelled:
                        throw ConnectionManagerError.connectionUnexpectedClosure
                    default:
                        continue
                    }
                }

                throw ConnectionManagerError.connectionUnexpectedClosure
            }

            group.addTask {
                try await Task.sleep(for: .seconds(4))
                throw ConnectionManagerError.connectionTimeout
            }

            try await group.next()

            group.cancelAll()
        }
    }

    // MARK: - Writing

    /// Asynchronously writes a single line to the network connection.
    ///
    /// This function ensures that the connection is in a ready state, then
    /// appends a newline character to the provided string, converts it to UTF-8
    /// encoded data, and sends it over the connection. It uses a continuation
    /// to await the completion of the send operation, throwing an error if the
    /// operation fails.
    ///
    /// - Parameter line: The string to be sent over the connection.
    /// - Throws: An error if the connection is not ready or if the send
    ///           operation encounters an error.
    private func writeLine(_ line: String) async throws {
        let connection = try ensureConnectionReady()

        let data = (line + "\n").data(using: .utf8)!

        try await withCheckedThrowingContinuation { (continuation:
            CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Escapes a given string for safe inclusion in a quoted context.
    ///
    /// This function escapes special characters in a string, such as
    /// backslashes, and optionally encloses the string in a quote character.
    ///
    /// - Parameters:
    ///   - string: The string to be escaped.
    ///   - quote: An optional quote character to enclose the escaped string.
    ///            Defaults to `"` if not provided.
    /// - Returns: A new string where special characters have been escaped and,
    ///            if a quote is provided, the string is enclosed by it.
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

    /// Constructs a filter clause for query commands.
    ///
    /// This function builds a filter clause of the form
    /// `(key comparator 'escapedValue')`. The provided `value` is first escaped
    /// using single quotes (via the `escape` function) to safely handle special
    /// characters. Afterwards, any backslashes in the resulting clause are
    /// further escaped. Finally, if the `quote` parameter is `true` (default),
    /// the entire clause is wrapped in double quotes.
    ///
    /// - Parameters:
    ///   - key: The field or attribute name to filter on.
    ///   - value: The value used in the comparison; it will be escaped for safe
    ///            insertion.
    ///   - comparator: The comparison operator (e.g., `==`, `!=`) used in the
    ///                 filter.
    ///   - quote: A Boolean value that determines whether the final clause
    ///            should be enclosed in double quotes. Defaults to `true`.
    /// - Returns: A formatted string representing the filter clause.
    private func filter(key: String, value: String, comparator: String = "==", quote: Bool = true) -> String {
        let clause = "(\(key) \(comparator) \(escape(value, quote: "'")))"
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return quote ? "\"\(clause)\"" : clause
    }

    // MARK: - Reading

    /// Asynchronously reads a complete line from the connection buffer.
    ///
    /// This function continuously attempts to extract a complete line by
    /// calling `extractLineFromBuffer()`.
    /// - If a complete line is available:
    ///   - If the line starts with `ACK`, it indicates a protocol error and
    ///     throws `ConnectionManagerError.protocolViolation` with the offending
    ///     line.
    ///   - Otherwise, it returns the line.
    /// - If no complete line is present, the function awaits additional data by
    ///   calling `receiveDataChunk()` and repeats the process.
    ///
    /// - Returns: An optional string representing the next complete line from
    ///            the buffer.
    /// - Throws: An error if a protocol error is encountered (i.e., a line
    ///           starting with `ACK`) or if underlying operations fail.
    private func readLine() async throws -> String? {
        while true {
            if let line = try extractLineFromBuffer() {
                if line.hasPrefix("ACK") {
                    throw ConnectionManagerError.protocolViolation(line)
                }

                return line
            }

            try await receiveDataChunk()
        }
    }

    /// Reads a fixed-length block of data asynchronously from the internal
    /// buffer.
    ///
    /// This function accumulates exactly `length` bytes by reading from the
    /// internal buffer. If the buffer does not contain enough data, it awaits
    /// additional data chunks via `receiveDataChunk()`. The function continues
    /// reading until the specified number of bytes have been collected.
    ///
    /// - Parameter length: The total number of bytes to read.
    /// - Returns: A `Data` object containing exactly `length` bytes.
    /// - Throws: An error if receiving additional data fails.
    private func readFixedLengthData(_ length: Int) async throws -> Data {
        guard length >= 0 else {
            throw ConnectionManagerError.malformedResponse(
                "Invalid data length requested: \(length)")
        }

        guard length > 0 else {
            return Data()
        }

        while buffer.count < length {
            try await receiveDataChunk()
        }

        guard buffer.count >= length else {
            throw ConnectionManagerError.connectionUnexpectedClosure
        }

        let data = Data(buffer.prefix(length))
        buffer.removeFirst(length)

        return data
    }

    /// Extracts a single line from the internal data buffer.
    ///
    /// This function searches for the first newline character (0x0A) in the
    /// buffer, and if found, it extracts all data up to (but not including) the
    /// newline. The extracted data is then removed from the buffer and
    /// converted into a UTF-8 encoded string. If the conversion fails, it
    /// throws a `ConnectionManagerError.malformedResponse`.
    ///
    /// - Returns: A string representing the extracted line, or `nil` if no
    ///            complete line (terminated by a newline) is available.
    /// - Throws: `ConnectionManagerError.malformedResponse` if the extracted
    ///           data cannot be converted to a valid UTF-8 string.
    private func extractLineFromBuffer() throws -> String? {
        guard let index = buffer.firstIndex(of: 0x0A) else {
            return nil
        }

        let data = Data(buffer[..<index])

        buffer.removeFirst(index + 1)

        guard let string = String(data: data, encoding: .utf8) else {
            throw ConnectionManagerError.malformedResponse(
                "Failed to decode line from buffer (invalid UTF-8)")
        }

        return string
    }

    /// Asynchronously receives a chunk of data from the network connection and
    /// appends it to the internal buffer.
    ///
    /// This function first ensures that the connection is ready by calling
    /// `ensureConnectionReady()`. It then initiates an asynchronous receive
    /// operation with a minimum of 1 byte and a maximum of `Mode.bufferSize`
    /// bytes. A checked continuation is used to await the result of the receive
    /// operation:
    /// - If data is received successfully, it is appended to the internal
    ///   `buffer`.
    /// - If the connection returns `nil` (indicating it is closed) or an error
    ///   occurs, an appropriate error is thrown.
    ///
    /// - Throws: An error if the connection is closed, if the receive operation
    ///           encounters an error, or if the connection is not in a ready
    ///           state.
    private func receiveDataChunk() async throws {
        let connection = try ensureConnectionReady()

        guard let chunk = try await withCheckedThrowingContinuation({ (
            continuation: CheckedContinuation<Data?, Error>) in
            connection.receive(minimumIncompleteLength: 1,
                               maximumLength: Mode.bufferSize)
            { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if isComplete {
                    continuation.resume(returning: data ?? Data())
                } else {
                    continuation.resume(returning: data)
                }
            }
        }) else {
            throw ConnectionManagerError.connectionUnexpectedClosure
        }

        buffer.append(contentsOf: chunk)
    }

    /// Groups an array of lines into chunks, starting a new chunk when a line
    /// begins with the specified prefix.
    ///
    /// This function iterates through the provided array of `lines` and
    /// partitions them into subarrays. A new chunk is initiated every time a
    /// line is encountered that starts with the given `prefix`, provided the
    /// current chunk is not empty. All lines, including the one that starts
    /// with the prefix, are included in their respective chunks.
    ///
    /// - Parameters:
    ///   - lines: An array of strings to be segmented into chunks.
    ///   - prefix: The prefix string that signifies the start of a new chunk.
    /// - Returns: An array of chunks, where each chunk is an array of strings
    ///            grouped together.
    private func chunkLines(_ lines: [String], startingWith prefix: String) ->
        [[String]]
    {
        var chunks = [[String]]()
        var currentChunk: [String]?

        for line in lines {
            if line.hasPrefix(prefix) {
                if let current = currentChunk {
                    chunks.append(current)
                }

                currentChunk = [line]
            } else {
                currentChunk?.append(line)
            }
        }

        if let current = currentChunk {
            chunks.append(current)
        }

        return chunks
    }

    /// Reads lines from the connection asynchronously until the specified
    /// condition is met.
    ///
    /// This function continuously calls `readLine()` to accumulate lines from
    /// the connection. Each line is appended to an array, and once a line
    /// satisfies the provided condition (as determined by the `condition`
    /// closure), the function returns the array of all collected lines,
    /// including the line that met the condition. If the stream ends without
    /// meeting the condition, the function throws a
    /// `ConnectionManagerError.readUntilConditionNotMet` error.
    ///
    /// - Parameter condition: A closure that receives a line of text and
    ///                        returns `true` when the desired condition is met.
    /// - Returns: An array of strings containing all lines read up to and
    ///            including the line that satisfies the condition.
    /// - Throws: `ConnectionManagerError.readUntilConditionNotMet` if the
    ///           condition is never met, or any error encountered by
    ///           `readLine()`.
    private func readUntil(_ condition: @escaping (String) -> Bool) async throws
        -> [String]
    {
        var lines: [String] = []

        while let line = try await readLine() {
            lines.append(line)

            if condition(line) {
                return lines
            }
        }

        throw ConnectionManagerError.readUntilConditionNotMet
    }

    /// Reads lines from the connection until a line starting with `OK` is
    /// encountered.
    ///
    /// This function is a convenience wrapper around `readUntil`, using a
    /// condition that checks if a line begin with `OK`. It returns all lines
    /// read up to and including the `OK` line. If the condition is never met or
    /// an error occurs during reading, the function will throw an error.
    ///
    /// - Returns: An array of strings containing the lines read, including the
    ///            final line that starts with `OK`.
    /// - Throws: `ConnectionManagerError.readUntilConditionNotMet` if the
    ///           condition is never met, or any error encountered by
    ///           `readLine()`.
    private func readUntilOK() async throws -> [String] {
        try await readUntil { $0.hasPrefix("OK") }
    }

    // MARK: - Parsing

    /// Parses a line into a key-value pair separated by a colon.
    ///
    /// This function splits the input line into two components using a colon
    /// (`:`) as the delimiter, with a maximum of one split. It trims whitespace
    /// from both components and converts the key to lowercase. If the line does
    /// not contain exactly one colon resulting in two parts, a
    /// `ConnectionManagerError.malformedResponse` error is thrown.
    ///
    /// - Parameter line: The string to be parsed, expected to be in the format
    ///                   `"key: value"`.
    /// - Returns: A tuple where the first element is the lowercase key and the
    ///            second element is the value.
    /// - Throws: `ConnectionManagerError.malformedResponse` if the line does
    ///           not contain exactly one colon.
    private func parseLine(_ line: String) throws -> (String, String) {
        let parts = line.split(separator: ":", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        guard parts.count == 2 else {
            throw ConnectionManagerError.malformedResponse(
                "Line does not contain exactly one colon")
        }

        return (parts[0].lowercased(), parts[1])
    }

    /// Parses a set of response lines from the media server into a `Song`
    /// object.
    ///
    /// This function processes an array of strings, each representing a line
    /// from an mpd server's response, and extracts key-value pairs using a
    /// colon (`:`) as the delimiter. It then maps these key-value pairs to the
    /// corresponding properties of a `Song` object.
    ///
    /// The function requires that the response includes mandatory fields `file`
    /// (used for the URL and id). If this field is not present, or if the
    /// response is malformed, a `ConnectionManagerError.malformedResponse` is
    /// thrown.
    ///
    /// Additionally, if an optional `index` is provided, it overrides the
    /// parsed `position` values. This workaround is used for responses (like
    /// those from `listplaylistinfo`) that do not include this field.
    ///
    /// - Parameters:
    ///   - lines: An array of strings representing the response lines from the
    ///            mpd server.
    ///   - album: An optional `Album` object to associate with the song. If
    ///            provided, it will be set as the album property of the song.
    ///   - index: An optional index value to use as the `position`.
    /// - Returns: An optional `Song` object if the response contains valid song
    ///           data; otherwise, it returns `nil`.
    /// - Throws: `ConnectionManagerError.malformedResponse` if mandatory fields
    ///           are missing or if the response is improperly formatted.
    private func parseSongResponse(_ lines: [String], index: Int? = nil) throws
        -> Song?
    {
        var id: UInt32?
        var position: UInt32?
        var url: URL?
        var artist: String?
        var album: String?
        var title: String?
        var track: Int?
        var disc: Int?
        var albumArtist: String?
        var duration: Double?

        for line in lines {
            guard line != "OK" else {
                break
            }

            let (key, value) = try parseLine(line)

            switch key {
            case "id":
                id = UInt32(value)
            case "pos":
                position = UInt32(value)
            case "file":
                guard let encoded = value.addingPercentEncoding(
                    withAllowedCharacters: .urlPathAllowed),
                    let formatted = URL(string: encoded)
                else {
                    throw ConnectionManagerError.malformedResponse(
                        "Failed to parse URL")
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
            case "disc":
                disc = Int(value)
            case "albumartist":
                albumArtist = value
            case "duration":
                duration = Double(value)
            default:
                break
            }
        }

        guard let url else {
            throw ConnectionManagerError.malformedResponse(
                "Missing mandatory url field")
        }

        // XXX: Not all repsonses provide a position, see:
        // https://github.com/MusicPlayerDaemon/MPD/issues/2330
        if position == nil, let index {
            position = UInt32(index)
        }

        return Song(
            identifier: id,
            position: position,
            url: url,
            artist: artist ?? "Unknown Artist",
            title: title ?? "Unknown Title",
            duration: duration ?? 0,
            disc: disc ?? 1,
            track: track ?? 1,
            album: Album(
                title: album ?? "Unknown Album",
                artist: Artist(name: albumArtist ?? "Unknown Artist")
            )
        )
    }
}

// MARK: - Shared commands

extension ConnectionManager {
    /// Retrieves the current status of the media player from the server.
    ///
    /// This asynchronous function sends a "status" command to the media server
    /// and parses the response to extract various status parameters:
    /// - `state`: The current player state, determined by the "state" key
    ///            (values "play", "pause", or "stop").
    /// - `isRandom`: A Boolean value indicating whether random playback is
    ///               enabled.
    /// - `isRepeat`: A Boolean value indicating whether repeat playback is
    ///               enabled.
    /// - `elapsed`: The elapsed playback time in seconds.
    /// - `playlist`: The last loaded playlist, identified by its name.
    /// - `song`: The currently playing song, identified by its song ID. For
    ///           this, an additional command ("playlistid") is executed to
    ///           retrieve song details.
    ///
    /// - Returns: A tuple containing:
    ///   - `state`: An optional `PlayerState` representing the current state of
    ///              the player.
    ///   - `isRandom`: An optional `Bool` indicating if random playback is
    ///                 enabled.
    ///   - `isRepeat`: An optional `Bool` indicating if repeat playback is
    ///                 enabled.
    ///   - `elapsed`: An optional `Double` representing the elapsed playback
    ///                time in seconds.
    ///   - `playlist`: An optional `Playlist` representing the last loaded
    ///                 playlist.
    ///   - `song`: An optional `Song` representing the currently playing song.
    /// - Throws: An error if the response from the media server is malformed or
    ///           if any underlying command execution fails.
    func getStatusData() async throws -> (state: PlayerState?, isRandom: Bool?,
                                          isRepeat: Bool?, elapsed: Double?,
                                          playlist: Playlist?, song: Song?, volume: Int?)
    {
        let lines = try await run(["status"])

        var state: PlayerState?
        var isRandom: Bool?
        var isRepeat: Bool?
        var elapsed: Double?
        var playlist: Playlist?
        var song: Song?
        var volume: Int?

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
                    throw ConnectionManagerError.malformedResponse(
                        "Invalid player state")
                }
            case "random":
                isRandom = (value == "1")
            case "repeat":
                isRepeat = (value == "1")
            case "elapsed":
                elapsed = Double(value)
            case "lastloadedplaylist":
                playlist = value == "" ? nil : Playlist(name: value)
            case "songid":
                let lines = try await run(["playlistid \(value)"])

                song = try parseSongResponse(lines)
            case "volume":
                volume = Int(value)
            default:
                break
            }
        }

        return (state, isRandom, isRepeat, elapsed, playlist, song, volume)
    }

    /// Retrieves the current database of albums from the media server.
    ///
    /// This asynchronous function sends a command to list all albums grouped by
    /// album artist and parses the response to construct an array of `Album`
    /// objects. Each `Album` object contains the album title and its associated
    /// artist.
    ///
    /// - Returns: An optional array of `Album` objects representing the albums
    ///            in the database. If no albums are found, it returns `nil`.
    /// - Throws: An error if the command execution fails or if the response is
    ///           malformed.
    func getDatabase() async throws -> [Album]? {
        let lines = try await run(["list album group albumartist"])

        var albums: [Album] = []
        var artist: Artist?

        for line in lines {
            guard line != "OK" else {
                break
            }

            let (key, value) = try parseLine(line)

            switch key {
            case "albumartist":
                artist = Artist(name: value.isEmpty ? "Unknown Artist" : value)
            case "album":
                guard let artist else {
                    throw ConnectionManagerError.malformedResponse(
                        "Album found without associated artist")
                }

                albums.append(Album(
                    title: value.isEmpty ? "Unknown Album" : value,
                    artist: artist
                ))
            default:
                continue
            }
        }

        return albums.sorted { $0.artist.name < $1.artist.name }
    }

    /// Retrieves all songs from the database or queue.
    ///
    /// - Parameter source: The source from which to retrieve the songs.
    /// - Returns: An array of `Song` objects representing all songs in the
    ///            database.
    /// - Throws: An error if the command execution fails or if the response is
    ///           malformed.
    func getSongs(from source: Source) async throws -> [Song] {
        let lines = switch source {
        case .database:
            try await run(["listallinfo"])
        case .queue:
            try await run(["playlistinfo"])
        case .playlist, .favorites:
            try await run(["listplaylistinfo \(escape(source.playlist!.name))"])
        }

        let chunks = chunkLines(lines, startingWith: "file")

        return try chunks.enumerated().compactMap { index, chunk in
            try parseSongResponse(chunk, index: index)
        }
    }

    /// Retrieves songs from the database or queue that match a specific album.
    ///
    /// - Parameters:
    ///   - album: The `Album` object for which the songs should be retrieved.
    ///   - source: The source from which to retrieve the songs.
    /// - Returns: An array of `Song` objects corresponding to the specified
    ///            album.
    /// - Throws: An error if the command execution fails or if the response is
    ///           malformed.
    func getSongs(in album: Album, from source: Source) async throws -> [Song] {
        let filters = "\"(\(filter(key: "album", value: album.title, quote: false)) AND \(filter(key: "albumartist", value: album.artist.name, quote: false)))\""

        let lines = switch source {
        case .database:
            try await run(["find \(filters)"])
        case .queue:
            try await run(["playlistfind \(filters)"])
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Only database and queue sources are supported for retrieving songs in an album")
        }

        let chunks = chunkLines(lines, startingWith: "file")

        return try chunks.compactMap { chunk in
            try parseSongResponse(chunk)
        }
    }

    func getAlbums(by artist: Artist, from source: Source) async throws -> [Album] {
        let lines: [String]

        switch source {
        case .database:
            let filterExpression = filter(key: "albumartist", value: artist.name)
            lines = try await run(["list album \(filterExpression)"])
        case .queue:
            let filters = "\"(\(filter(key: "albumartist", value: artist.name, quote: false)))\""
            lines = try await run(["playlistfind \(filters)"])
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Only database and queue sources are supported for retrieving albums by artist")
        }

        switch source {
        case .database:
            var albums: [Album] = []

            for line in lines {
                guard line != "OK" else { break }

                let (key, value) = try parseLine(line)
                if key == "album" {
                    albums.append(Album(title: value.isEmpty ? "Unknown Album" : value, artist: artist))
                }
            }

            return albums
        case .queue:
            let chunks = chunkLines(lines, startingWith: "file")
            var albumTitles = Set<String>()

            for chunk in chunks {
                for line in chunk {
                    let (key, value) = try parseLine(line)
                    if key == "album" {
                        albumTitles.insert(value.isEmpty ? "Unknown Album" : value)
                    }
                }
            }

            return albumTitles.map { Album(title: $0, artist: artist) }
        default:
            return []
        }
    }

    /// Retrieves the URL of the first song in an album.
    ///
    /// This is a more efficient method than fetching all songs when only the first
    /// song's URL is needed (e.g., for artwork retrieval).
    ///
    /// - Parameter album: The album to retrieve the first song URL from.
    /// - Returns: The URL of the first song in the album.
    /// - Throws: An error if the command execution fails, if the album's artist is
    ///           not set, or if no songs are found in the album.
    func getURL(of album: Album) async throws -> URL {
        let filters = "\"(\(filter(key: "album", value: album.title, quote: false)) AND \(filter(key: "albumartist", value: album.artist.name, quote: false)))\""

        let lines = try await run(["find \(filters) window 0:1"])
        guard !lines.isEmpty, lines.first != "OK" else {
            throw ConnectionManagerError.malformedResponse(
                "No songs found in album: \(album.title)")
        }

        for line in lines {
            guard line != "OK" else {
                break
            }

            let (key, value) = try parseLine(line)

            if key == "file" {
                guard let encoded = value.addingPercentEncoding(
                    withAllowedCharacters: .urlPathAllowed),
                    let formatted = URL(string: encoded)
                else {
                    throw ConnectionManagerError.malformedResponse(
                        "Failed to parse URL")
                }

                return formatted
            }
        }

        throw ConnectionManagerError.malformedResponse(
            "No file URL found in response for album: \(album.title)")
    }

    /// Retrieves all playlists.
    ///
    /// - Returns: An array of `Playlist` objects representing the available
    ///            playlists.
    /// - Throws: An error if the command execution fails or if the response is
    ///           malformed.
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
                playlists.append(Playlist(name: value))

                index += 1
            }
        }

        return playlists
    }
}

// MARK: - Idle mode commands

extension ConnectionManager where Mode == IdleMode {
    static let idle = ConnectionManager<IdleMode>()

    /// Waits for an idle event from the media server that matches the specified
    /// mask.
    ///
    /// - Parameter mask: An array of `IdleEvent` values specifying which events
    ///                   to listen for.
    /// - Returns: The `IdleEvent` that triggered the idle state, as indicated
    ///            by the server response.
    /// - Throws: A `ConnectionManagerError.malformedResponse` if the server
    ///           response does not contain a `changed` line.
    func idleForEvents(mask: [IdleEvent]) async throws -> IdleEvent {
        let lines = try await run(["idle \(mask.map(\.rawValue).joined(separator: " "))"])
        guard let changedLine = lines.first(where: { $0.hasPrefix(
            "changed: ") })
        else {
            throw ConnectionManagerError.malformedResponse(
                "Missing 'changed' line")
        }

        let changed = String(changedLine.dropFirst("changed: ".count))
        guard let event = IdleEvent(rawValue: changed) else {
            throw ConnectionManagerError.malformedResponse(
                "Received unknown idle event: \(changed)")
        }

        return event
    }
}

// MARK: - Artwork mode commands

extension ConnectionManager where Mode == ArtworkMode {
    /// Retrieves the complete artwork data for a given URL by fetching it in
    /// chunks from the media server.
    ///
    /// - Parameter url: The URL representing the artwork resource on the
    ///                  server.
    /// - Returns: A `Data` object containing the complete binary artwork data.
    /// - Throws: An error if the server response is malformed, if the read
    ///           operation fails, or if other connection related errors occur.
    func getArtworkData(for url: URL) async throws -> Data {
        @AppStorage(Setting.artworkGetter) var artworkGetter = ArtworkGetter.library

        var data = Data()
        var offset = 0
        var totalSize: Int?

        loop: while true {
            try await writeLine("\(artworkGetter.rawValue) \(escape(url.path)) \(offset)")

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

// MARK: - Command mode commands

extension ConnectionManager where Mode == CommandMode {
    static func command() async throws -> ConnectionManager<CommandMode> {
        let manager = ConnectionManager<CommandMode>()
        try await manager.connect()

        return manager
    }

    /// Loads a playlist into queue.
    ///
    /// This asynchronous function clears the queue on the media server
    /// and then loads new content based on the provided parameter:
    /// - If a `Playlist` object is provided, it clears the queue and loads the
    ///   specified playlist using its name.
    /// - If no playlist is provided (`nil`), it clears the queue and adds all
    ///   songs from the music directory.
    ///
    /// - Parameter playlist: An optional `Playlist` object. When provided, its
    ///                       `name` is used to load the corresponding playlist.
    /// - Throws: An error if the underlying command execution fails.
    func loadPlaylist(_ playlist: Playlist? = nil) async throws {
        if let playlist {
            _ = try await run(["clear", "load \(escape(playlist.name))"])
        } else {
            _ = try await run(["clear", "add /"])
        }
    }

    /// Clears the current queue.
    ///
    /// - Throws: An error if the underlying command execution fails.
    func clearQueue() async throws {
        _ = try await run(["clear"])
    }

    /// Creates a new playlist with the specified name.
    ///
    /// - Parameter name: The name of the new playlist to create.
    /// - Throws: An error if the underlying command execution fails.
    func createPlaylist(named name: String) async throws {
        _ = try await run(["save \(escape(name))", "playlistclear \(escape(name))"])
    }

    /// Renames a playlist.
    ///
    /// - Parameters:
    ///   - playlist: The `Playlist` object representing the playlist to rename.
    ///   - name: The new name for the playlist.
    /// - Throws: An error if the underlying command execution fails.
    func renamePlaylist(_ playlist: Playlist, to name: String) async throws {
        _ = try await run(["rename \(escape(playlist.name)) \(escape(name))"])
    }

    /// Removes a playlist from the media server.
    ///
    /// - Parameter playlist: The `Playlist` object representing the playlist to
    ///                       remove.
    /// - Throws: An error if the underlying command execution fails.
    func removePlaylist(_ playlist: Playlist) async throws {
        _ = try await run(["rm \(escape(playlist.name))"])
    }

    /// Updates the media server's database.
    ///
    /// This function triggers a database update on the media server, which
    /// causes it to rescan the music directory and update its internal
    /// database.
    ///
    /// - Parameter force: A Boolean value indicating whether to force a rescan
    ///                   (`true`) or perform a standard update (`false`).
    /// - Throws: An error if the underlying command execution fails
    func update(force: Bool = false) async throws {
        if force {
            _ = try await run(["rescan"])
        } else {
            _ = try await run(["update"])
        }
    }

    /// Adds songs to the specified source (queue or playlist).
    ///
    /// - Parameters:
    ///   - songs: An array of `Song` objects to add.
    ///   - source: The destination source (queue or playlist).
    /// - Throws: An error if the underlying command execution fails.
    func add(songs: [Song], to source: Source) async throws {
        guard !songs.isEmpty else {
            return
        }

        let existingSongs = try await getSongs(from: source)
        let songsToAdd = songs.filter { song in
            !existingSongs.contains { $0.url == song.url }
        }

        let commands: [String]
        switch source {
        case .queue:
            commands = songsToAdd.map {
                "add \(escape($0.url.path))"
            }
        case .playlist, .favorites:
            guard let playlist = source.playlist else {
                throw ConnectionManagerError.unsupportedOperation(
                    "Playlist is required for adding songs to a playlist")
            }

            commands = songsToAdd.map {
                "playlistadd \(playlist.name) \(escape($0.url.path))"
            }
        case .database:
            throw ConnectionManagerError.unsupportedOperation(
                "Cannot add songs to the database")
        }

        _ = try await run(commands)
    }

    /// Removes songs from the specified source (queue or playlist).
    ///
    /// - Parameters:
    ///   - songs: An array of `Song` objects to remove.
    ///   - source: The source from which to remove the songs.
    /// - Throws: An error if the underlying command execution fails.
    func remove(songs: [Song], from source: Source) async throws {
        guard !songs.isEmpty else {
            return
        }

        let sourceSongs = try await getSongs(from: source)
        let urls = songs.map(\.url)
        let positions = sourceSongs
            .compactMap { song in
                urls.contains(song.url) ? song.position : nil
            }
            .sorted(by: >)

        guard !positions.isEmpty else {
            return
        }

        var commands = [String]()

        var i = 0
        while i < positions.count {
            let start = positions[i]
            var end = start

            while i + 1 < positions.count, positions[i + 1] + 1 == end {
                i += 1
                end = positions[i]
            }

            switch source {
            case .queue:
                if start == end {
                    commands.append("delete \(start)")
                } else {
                    commands.append("delete \(end):\(start + 1)")
                }
            case .playlist, .favorites:
                let playlist = source.playlist!
                if start == end {
                    commands.append("playlistdelete \(escape(playlist.name)) \(start)")
                } else {
                    for pos in stride(from: Int(start), through: Int(end), by: -1) {
                        commands.append("playlistdelete \(escape(playlist.name)) \(pos)")
                    }
                }
            default:
                throw ConnectionManagerError.unsupportedOperation(
                    "Only queue and playlist sources are supported for removing songs")
            }

            i += 1
        }

        _ = try await run(commands)
    }

    /// Moves a song to a specific position in the specified source.
    ///
    /// - Parameters:
    ///   - song: The `Song` object representing the item to move.
    ///   - position: The destination position for the item.
    ///   - source: The source in which to move the item.
    /// - Throws: An error if the underlying command execution fails.
    func move(_ song: Song, to position: Int, in source: Source) async throws {
        guard let currentPosition = song.position else {
            throw ConnectionManagerError.unsupportedOperation(
                "Cannot move song without a position")
        }

        switch source {
        case .queue:
            _ = try await run(["move \(currentPosition) \(position)"])
        case .playlist, .favorites:
            guard let playlist = source.playlist else {
                throw ConnectionManagerError.unsupportedOperation(
                    "Playlist is required for adding songs to a playlist")
            }

            _ = try await run(["playlistmove \(escape(playlist.name)) \(currentPosition) \(position)"])
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Only queue and playlist sources are supported for moving media")
        }
    }

    /// Plays a media object (Song, Album, or Artist).
    ///
    /// - Parameter media: The media object to play.
    /// - Throws: An error if the underlying command execution fails.
    func play(_ media: any Mediable) async throws {
        // Check if it's a Song with an identifier
        if let song = media as? Song, let id = song.identifier {
            _ = try await run(["playid \(id)"])
            return
        }

        let songs: [Song]
        switch media {
        case let album as Album:
            songs = try await getSongs(in: album, from: .database)
        case let artist as Artist:
            // For artists, we need to get all songs by that artist
            let filter = filter(key: "artist", value: artist.name)
            let lines = try await run(["find \(filter)"])
            let chunks = chunkLines(lines, startingWith: "file")
            songs = try chunks.compactMap { chunk in
                try parseSongResponse(chunk)
            }
        case let song as Song:
            songs = [song]
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Only Album, Artist, and Song types are supported for playback")
        }

        guard !songs.isEmpty else {
            throw ConnectionManagerError.malformedResponse(
                "No songs found for the specified media")
        }

        let queue = try await getSongs(from: .queue)

        var id: UInt32?
        var commands = [String]()

        for (index, song) in songs.enumerated() {
            if let existingSong = queue.first(where: { $0.url == song.url }) {
                if index == 0 {
                    id = existingSong.identifier
                }
            } else {
                commands.append("addid \(escape(song.url.path))")
            }
        }

        if !commands.isEmpty {
            let responses = try await run(commands)

            if id == nil {
                for response in responses {
                    if response.hasPrefix("Id: ") {
                        id = UInt32(response.dropFirst(4))
                        break
                    }
                }
            }
        }

        guard let id else {
            throw ConnectionManagerError.malformedResponse(
                "Failed to determine song ID to play")
        }

        _ = try await run(["playid \(id)"])
    }

    /// Toggle playback.
    ///
    /// - Parameter value: A Boolean value indicating whether to pause (`true`)
    ///                    or resume (`false`) playback.
    /// - Throws: An error if the underlying command execution fails.
    func pause(_ value: Bool) async throws {
        _ = try await run([value ? "pause 1" : "pause 0"])
    }

    /// Play the previous song in the queue.
    ///
    /// - Throws: An error if the underlying command execution fails.
    func previous() async throws {
        _ = try await run(["previous"])
    }

    /// Play the next song in the queue.
    ///
    /// - Throws: An error if the underlying command execution fails.
    func next() async throws {
        _ = try await run(["next"])
    }

    /// Toggle repeat mode.
    ///
    /// - Parameter value: A Boolean value indicating whether to enable (`true`)
    ///                    or disable (`false`) repeat mode.
    /// - Throws: An error if the underlying command execution fails.
    func `repeat`(_ value: Bool) async throws {
        _ = try await run([value ? "repeat 1" : "repeat 0"])
    }

    /// Toggle random mode.
    ///
    /// - Parameter value: A Boolean value indicating whether to enable (`true`)
    ///                    or disable (`false`) random mode.
    /// - Throws: An error if the underlying command execution fails.
    func random(_ value: Bool) async throws {
        _ = try await run([value ? "random 1" : "random 0"])
    }

    /// Seek to a specific position in the currently playing song.
    ///
    /// - Parameter value: The position to seek to, represented as a percentage
    ///                    of the song's total duration.
    /// - Throws: An error if the underlying command execution fails.
    func seek(_ value: Double) async throws {
        _ = try await run(["seekcur \(value)"])
    }

    /// Set the volume level.
    ///
    /// - Parameter volume: The volume level to set (0-100).
    /// - Throws: An error if the underlying command execution fails.
    func setVolume(_ volume: Int) async throws {
        _ = try await run(["setvol \(volume)"])
    }
}
