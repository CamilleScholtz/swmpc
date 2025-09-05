//
//  ConnectionManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import DequeModule
import Network
import SwiftUI

/// Protocol defining the configuration for different connection modes to the
/// MPD server. Each mode can have different performance characteristics and
/// buffer sizes.
protocol ConnectionMode: Sendable {
    /// A label identifying the connection mode.
    nonisolated static var label: String { get }
    /// Whether to enable TCP keepalive for this connection.
    nonisolated static var enableKeepalive: Bool { get }
    /// The buffer size to use for reading data.
    nonisolated static var bufferSize: Int { get }
    /// The dispatch queue attributes for this connection mode.
    nonisolated static var queueAttributes: DispatchQueue.Attributes { get }
    /// The quality of service level for operations.
    nonisolated static var qos: DispatchQoS { get }
}

/// Connection mode for idle operations that listen for MPD server events.
/// Uses keepalive to maintain long-lived connections.
nonisolated enum IdleMode: ConnectionMode {
    static let label = "idle"
    static let enableKeepalive = true
    static let bufferSize = 4096
    static let queueAttributes: DispatchQueue.Attributes = []
    static let qos: DispatchQoS = .utility
}

/// Connection mode for artwork retrieval operations.
/// Uses larger buffers and concurrent queue for efficient image data transfer.
nonisolated enum ArtworkMode: ConnectionMode {
    static let label = "artwork"
    static let enableKeepalive = false
    static let bufferSize = 8192
    static let queueAttributes: DispatchQueue.Attributes = []
    static let qos: DispatchQoS = .utility
}

/// Connection mode for executing MPD commands.
/// Optimized for quick command execution with higher priority.
nonisolated enum CommandMode: ConnectionMode {
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

    nonisolated var errorDescription: String? {
        switch self {
        case .invalidPort:
            "Invalid port provided. Port must be between 1 and 65535."
        case .unsupportedServerVersion:
            "Unsupported MPD server version. Minimum required version is 0.22."
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
    /// The underlying network connection to the MPD server.
    private var connection: NWConnection?

    /// Dispatch queue for network operations configured based on the connection
    /// mode.
    private let connectionQueue = DispatchQueue(
        label: "com.camille.swmpc.connection.\(Mode.label)",
        qos: Mode.qos,
        attributes: Mode.queueAttributes,
        target: .global(qos: Mode.qos.qosClass),
    )

    /// Buffer for accumulating incoming data from the network connection.
    private var buffer = Deque<UInt8>()

    /// The version of the MPD server obtained during connection handshake.
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
        guard connection?.state != .ready else {
            return
        }

        let options = NWProtocolTCP.Options()
        options.noDelay = true
        options.enableKeepalive = Mode.enableKeepalive

        var portNumber = UserDefaults.standard.integer(forKey: Setting.port)
        portNumber = portNumber == 0 ? 6600 : portNumber
        guard portNumber > 0, portNumber <= 65535,
              let port = NWEndpoint.Port(rawValue: UInt16(portNumber))
        else {
            throw ConnectionManagerError.invalidPort
        }

        let host = UserDefaults.standard.string(forKey: Setting.host) ?? "localhost"
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: port,
            using: NWParameters(tls: nil, tcp: options),
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
    /// Cancels any active connection, sets the connection to `nil`, removes all
    /// buffered data, and resets the server version. This method should be
    /// called to cleanly terminate the connection.
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
    /// This function checks the version of the MPD server obtained after
    /// connecting. The minimum supported version is 0.22. If the version is
    /// `nil` (not yet known), the check passes.
    ///
    /// - Throws: `ConnectionManagerError.unsupportedServerVersion` if the
    ///           server version is older than the minimum required.
    func ensureVersionSupported() throws {
        guard version?.compare("0.22", options: .numeric) !=
            .orderedAscending
        else {
            throw ConnectionManagerError.unsupportedServerVersion
        }
    }

    /// Ensures that the client is authenticated with the server.
    ///
    /// This function checks if a password is set and sends it to the server for
    /// authentication. If no password is set, the function returns immediately.
    ///
    /// - Throws: An error if the authentication command fails.
    func ensureAuthenticated() async throws {
        let password = UserDefaults.standard.string(forKey: Setting.password) ?? ""
        guard !password.isEmpty else {
            return
        }

        try await run(["password", password])
    }

    /// Sends a ping command to the server.
    ///
    /// - Throws: An error if the command fails.
    func ping() async throws {
        try await run(["ping"])
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
    @discardableResult
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

        guard let data = (line + "\n").data(using: .utf8) else {
            throw ConnectionManagerError.protocolViolation(
                "Failed to encode command to UTF-8.")
        }

        try await withCheckedThrowingContinuation { (continuation:
            CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed {
                error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    /// Escapes a given string for safe inclusion in MPD commands.
    ///
    /// This function escapes special characters in a string, such as
    /// backslashes and quotes, and optionally encloses the string in a quote character.
    ///
    /// - Parameters:
    ///   - string: The string to be escaped.
    ///   - quote: An optional quote character to enclose the escaped string.
    ///            Defaults to `"` if not provided.
    /// - Returns: A new string where special characters have been escaped and,
    ///            if a quote is provided, the string is enclosed by it.
    private nonisolated func escape(_ string: String, quote: String? = "\"")
        -> String
    {
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

    /// Constructs a filter clause for MPD query commands like `find` or
    /// `search`.
    ///
    /// This function builds a filter clause suitable for an MPD command. The
    /// provided `value` is escaped to handle special characters safely. The
    /// resulting clause is typically of the form `"(key 'escapedValue')"`. The
    /// entire clause is then escaped for safe inclusion in a command string.
    ///
    /// - Parameters:
    ///   - key: The tag or attribute to filter on (e.g., "artist", "album").
    ///   - value: The value to match against. It will be escaped.
    ///   - comparator: The comparison operator (e.g., "==", "!="). Defaults
    ///                 to "==".
    ///   - quote: A Boolean indicating whether to enclose the final clause in
    ///            double quotes. Defaults to `true`.
    /// - Returns: A formatted and escaped string representing the filter
    ///            clause.
    private nonisolated func filter(key: String, value: String, comparator:
        String = "==", quote: Bool = true) -> String
    {
        let clause = "(\(key) \(comparator) \(escape(value, quote: "'")))"
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        return quote ? "\"\(clause)\"" : clause
    }

    // MARK: - Reading

    /// Asynchronously reads a complete line from the connection buffer.
    ///
    /// This function continuously attempts to extract a complete line by
    /// calling `extractLineFromBuffer()`. If no complete line is present, it
    /// awaits additional data by calling `receiveDataChunk()` and repeats the
    /// process.
    ///
    /// If a line starts with `ACK`, it indicates a protocol error, and the
    /// function throws `ConnectionManagerError.protocolViolation`.
    ///
    /// - Returns: A string representing the next complete line from the buffer.
    /// - Throws: An error if a protocol error is encountered or if underlying
    ///           I/O operations fail.
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

    /// Asynchronously receives a chunk of data from the network connection.
    ///
    /// This function first ensures that the connection is ready. It then
    /// initiates an asynchronous receive operation.
    ///
    /// - Throws: An error if the connection is not ready or if the receive
    ///           operation encounters an error.
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
    private nonisolated func chunkLines(_ lines: [String], startingWith prefix:
        String) -> [[String]]
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
    /// satisfies the provided `condition` closure, the function returns all
    /// collected lines.
    ///
    /// - Parameter condition: A closure that receives a line of text and
    ///                        returns `true` when the desired condition is met.
    /// - Returns: An array of strings containing all lines read up to and
    ///            including the line that satisfies the condition.
    /// - Throws: An error if any underlying `readLine()` call fails.
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
    /// condition that checks if a line begins with `OK`. It returns all lines
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
    private nonisolated func parseLine(_ line: String) throws -> (String,
                                                                  String)
    {
        let parts = line.split(separator: ":", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        guard parts.count == 2 else {
            throw ConnectionManagerError.malformedResponse(
                "Line does not contain exactly one colon")
        }

        return (parts[0].lowercased(), parts[1])
    }

    /// A private helper to safely cast a value to a generic type `T`.
    ///
    /// - Parameter value: The value to be cast.
    /// - Returns: The value cast to type `T`.
    /// - Throws: `ConnectionManagerError.malformedResponse` if the cast fails.
    private nonisolated func castResult<T>(_ value: some Any) throws -> T {
        guard let result = value as? T else {
            throw ConnectionManagerError.malformedResponse(
                "Type mismatch: expected \(T.self) but created \(type(of: value))")
        }

        return result
    }

    /// Parses response lines into a single media object of a specified generic
    /// type.
    ///
    /// This function processes key-value pairs from MPD response lines and uses
    /// them to initialize a `Song`, `Album`, or `Artist` object, which is then
    /// cast to the requested generic type `T`.
    ///
    /// - Parameters:
    ///   - lines: An array of strings representing the response lines from MPD.
    ///   - type: The `MediaType` (.song, .album, .artist) to guide the initial
    ///           parsing.
    ///   - index: An optional index, typically used to set a song's position.
    /// - Returns: A media object cast to the generic type `T`.
    /// - Throws: `ConnectionManagerError.malformedResponse` if mandatory fields
    ///           are missing, the response is improperly formatted, or the
    ///           created object cannot be cast to `T`.
    private nonisolated func parseMediaResponse<T>(_ lines: [String], as type:
        MediaType, index: Int? = nil) throws -> T
    {
        var fields: [String: String] = [:]
        for line in lines where line != "OK" {
            let (key, value) = try parseLine(line)
            fields[key] = value
        }

        guard let file = fields["file"], let encoded = file
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: encoded)
        else {
            throw ConnectionManagerError.malformedResponse(
                "Missing or invalid URL field")
        }

        let artistName = fields["albumartist"] ?? fields["artist"] ?? "Unknown Artist"

        switch type {
        case .song:
            let song = Song(
                url: url,
                identifier: fields["id"].flatMap { UInt32($0) },
                position: fields["pos"].flatMap { UInt32($0) }
                    ?? index.map { UInt32($0) },
                artist: fields["artist"] ?? "Unknown Artist",
                title: fields["title"] ?? "Unknown Title",
                duration: fields["duration"].flatMap { Double($0) } ?? 0,
                disc: fields["disc"].flatMap { Int($0) } ?? 1,
                track: fields["track"].flatMap { Int($0) } ?? 1,
                genre: fields["genre"],
                album: Album(
                    url: url,
                    title: fields["album"] ?? "Unknown Album",
                    genre: fields["genre"],
                    artist: Artist(
                        url: url,
                        name: artistName,
                    ),
                ),
            )

            return try castResult(song)
        case .album:
            let album = Album(
                url: url,
                title: fields["album"] ?? "Unknown Album",
                genre: fields["genre"],
                artist: Artist(
                    url: url,
                    name: artistName,
                ),
            )

            return try castResult(album)
        case .artist:
            let artist = Artist(
                url: url,
                name: artistName,
            )

            return try castResult(artist)
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Unsupported media type: \(type)")
        }
    }

    /// Parses response lines into an array of media objects of a specified
    /// generic type.
    ///
    /// This function chunks the response lines (typically by a "file:" line)
    /// and processes each chunk to create a `Song`, `Album`, or `Artist`
    /// object. The resulting objects are then cast to the requested generic
    /// type `T`.
    ///
    /// - Parameters:
    ///   - lines: An array of strings from an MPD response.
    ///   - type: The `MediaType` (.song, .album, .artist) to guide the parsing
    ///           of each chunk.
    ///   - index: If `true`, uses the enumeration index of each chunk as the
    ///            song's position.
    /// - Returns: An array of media objects, each cast to the generic type `T`.
    /// - Throws: An error if parsing of any chunk fails.
    @concurrent
    private nonisolated func parseMediaResponse<T>(_ lines: [String], as type:
        MediaType, index: Bool = false) async throws -> [T]
    {
        let chunks = chunkLines(lines, startingWith: "file")

        if index {
            return try chunks.enumerated().compactMap { index, chunk in
                try parseMediaResponse(chunk, as: type, index: index)
            }
        }

        return try chunks.compactMap { chunk in
            try parseMediaResponse(chunk, as: type)
        }
    }
}

// MARK: - Shared commands

extension ConnectionManager {
    /// Retrieves the current status of the media player from the server.
    ///
    /// This asynchronous function sends a command list containing "status" and
    /// "currentsong" to the server. It parses the combined response to extract
    /// various status parameters and the full details of the currently playing
    /// song, avoiding the need for a second network call.
    ///
    /// - Returns: A tuple containing:
    ///   - `state`: The current player state (`play`, `pause`, or `stop`).
    ///   - `isConsume`: A Boolean indicating if consume playback is enabled.
    ///   - `isRandom`: A Boolean indicating if random playback is enabled.
    ///   - `isRepeat`: A Boolean indicating if repeat playback is enabled.
    ///   - `elapsed`: The elapsed playback time in seconds.
    ///   - `song`: The currently playing song, if any.
    ///   - `volume`: The current volume level (0-100).
    /// - Throws: An error if the response is malformed or if the underlying
    ///           command execution fails.
    func getStatusData() async throws -> (state: PlayerState?, isRandom: Bool?,
                                          isRepeat: Bool?, isConsume: Bool?,
                                          elapsed: Double?, song: Song?, volume:
                                          Int?)
    {
        let lines = try await run(["status", "currentsong"])

        var fields: [String: String] = [:]
        for line in lines where line != "OK" {
            let (key, value) = try parseLine(line)
            fields[key] = value
        }

        let state: PlayerState?
        if let stateValue = fields["state"] {
            switch stateValue {
            case "play": state = .play
            case "pause": state = .pause
            case "stop": state = .stop
            default:
                throw ConnectionManagerError.malformedResponse(
                    "Invalid player state: \(stateValue)")
            }
        } else {
            state = nil
        }

        let isConsume = fields["consume"].map { $0 == "1" }
        let isRandom = fields["random"].map { $0 == "1" }
        let isRepeat = fields["repeat"].map { $0 == "1" }
        let elapsed = fields["elapsed"].flatMap(Double.init)
        let volume = fields["volume"].flatMap(Int.init)

        let song: Song? = if fields["file"] != nil {
            try parseMediaResponse(fields.map {
                "\($0.key): \($0.value)"
            }, as: .song)
        } else {
            nil
        }

        return (state, isConsume, isRandom, isRepeat, elapsed, song, volume)
    }

    /// Retrieves all unique albums from the database, sorted as specified.
    ///
    /// This method fetches a list of songs (specifically, the first track of
    /// each album) and then extracts the unique albums from that list.
    ///
    /// - Note: We currently use the `find` command to retrieve albums. I'd
    ///         rather use `list`, but that has no sort option.
    ///
    /// - Parameter sort: The sorting descriptor containing the option and
    ///                   direction for sorting albums.
    /// - Returns: An array of unique `Album` objects.
    /// - Throws: An error if the command fails or the response is malformed.
    func getAlbums(sort: SortDescriptor = SortDescriptor(option: .artist)) async
        throws -> [Album]
    {
        let lines = try await run(["find \(filter(key: "track", value: "1")) sort \(sort.direction.rawValue)\(sort.option.rawValue)"])

        let albums: [Album] = try await parseMediaResponse(lines, as: .album)

        var seen: Set<String> = []
        var unique: [Album] = []

        for album in albums {
            if !seen.contains(album.id) {
                unique.append(album)
                seen.insert(album.id)
            }
        }

        return unique
    }

    /// Retrieves all albums by a specific artist from the given source.
    ///
    /// - Parameters:
    ///   - artist: The `Artist` to find albums for.
    ///   - source: The source to search within (either `.database` or
    ///             `.queue`).
    /// - Returns: An array of `Album` objects by the specified artist.
    /// - Throws: `ConnectionManagerError.unsupportedOperation` if the source is
    ///           not the database or queue.
    func getAlbums(by artist: Artist, from source: Source) async throws ->
        [Album]
    {
        let lines: [String]

        switch source {
        case .database:
            lines = try await run(["find \(filter(key: "albumartist", value: artist.name)) sort date"])
        case .queue:
            lines = try await run(["playlistfind \(filter(key: "albumartist", value: artist.name)) sort date"])
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Only database and queue sources are supported for retrieving albums by artist")
        }

        let albums: [Album] = try await parseMediaResponse(lines, as: .album)

        var seen: Set<String> = []
        var unique: [Album] = []

        for album in albums {
            if !seen.contains(album.id) {
                unique.append(album)
                seen.insert(album.id)
            }
        }

        return unique
    }

    /// Retrieves all unique artists from the database.
    ///
    /// This method first retrieves all unique albums and then extracts the
    /// unique artists from that list.
    ///
    /// - Parameter sort: The sorting descriptor used to retrieve albums, which
    ///                   indirectly affects the artist order.
    /// - Returns: An array of unique `Artist` objects.
    /// - Throws: An error if the underlying album lookup fails.
    func getArtists(sort: SortDescriptor = SortDescriptor(option: .artist))
        async throws -> [Artist]
    {
        let albums = try await getAlbums(sort: sort)

        var seen: Set<String> = []
        var unique: [Artist] = []

        for album in albums {
            let artist = album.artist

            if !seen.contains(artist.id) {
                unique.append(artist)
                seen.insert(artist.id)
            }
        }

        return unique
    }

    /// Retrieves all songs from a specified source.
    ///
    /// - Parameters:
    ///   - source: The source (`.database`, `.queue`, or a specific
    ///             `.playlist`) from which to retrieve the songs.
    ///   - sort: The sorting descriptor for database queries. Ignored for queue
    ///           and playlist sources.
    /// - Returns: An array of `Song` objects from the specified source.
    /// - Throws: An error if the command execution fails or if the response is
    ///           malformed.
    func getSongs(from source: Source, sort: SortDescriptor = SortDescriptor(
        option: .artist)) async throws -> [Song]
    {
        let lines = switch source {
        case .database:
            try await run(["find \"(title != '')\" sort \(sort.direction.rawValue)\(sort.option.rawValue)"])
        case .queue:
            try await run(["playlistinfo"])
        case .playlist, .favorites:
            try await run(["listplaylistinfo \(escape(source.playlist!.name))"])
        }

        return try await parseMediaResponse(lines, as: .song, index: true)
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

        return try await parseMediaResponse(lines, as: .song)
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
    /// Shared singleton instance for idle connection management.
    /// Used for listening to server events without blocking other operations.
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
    /// Creates and connects a new `ConnectionManager` for artwork operations.
    ///
    /// - Returns: A connected `ConnectionManager<ArtworkMode>` instance.
    /// - Throws: An error if the connection fails.
    static func artwork() async throws -> ConnectionManager<ArtworkMode> {
        let manager = ConnectionManager<ArtworkMode>()
        try await manager.connect()

        return manager
    }

    /// Retrieves the complete artwork data for a given URL by fetching it in
    /// chunks from the media server.
    ///
    /// - Parameter url: The URL representing the artwork resource on the
    ///                  server.
    /// - Returns: A `Data` object containing the complete binary artwork data.
    /// - Throws: An error if the server response is malformed, if the read
    ///           operation fails, or if other connection related errors occur.
    func getArtworkData(for url: URL) async throws -> Data {
        var data = Data()
        var offset = 0
        var totalSize: Int?

        loop: while true {
            let artworkGetterRaw = UserDefaults.standard.string(forKey: Setting.artworkGetter) ?? ArtworkGetter.library.rawValue
            try await writeLine("\(artworkGetterRaw) \(escape(url.path)) \(offset)")

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
    /// Creates and connects a new `ConnectionManager` for command execution.
    ///
    /// This factory method provides a convenient way to get a ready-to-use
    /// connection manager instance pre-configured for sending commands.
    ///
    /// - Returns: A connected `ConnectionManager<CommandMode>` instance.
    /// - Throws: An error if the connection fails.
    static func command() async throws -> ConnectionManager<CommandMode> {
        let manager = ConnectionManager<CommandMode>()
        try await manager.connect()

        return manager
    }

    /// Loads a playlist into the queue.
    ///
    /// This function clears the current queue and then loads new content:
    /// - If a `Playlist` object is provided, it loads the specified playlist.
    /// - If no playlist is provided (`nil`), it adds all songs from the music
    ///   directory.
    ///
    /// - Parameter playlist: An optional `Playlist` object. When provided, its
    ///                       `name` is used to load the corresponding playlist.
    /// - Throws: An error if the underlying command execution fails.
    func loadPlaylist(_ playlist: Playlist? = nil) async throws {
        if let playlist {
            try await run(["clear", "load \(escape(playlist.name))"])
        } else {
            try await run(["clear", "add /"])
        }
    }

    /// Clears the current queue.
    ///
    /// - Throws: An error if the underlying command execution fails.
    func clearQueue() async throws {
        try await run(["clear"])
    }

    /// Creates a new, empty playlist with the specified name.
    ///
    /// This command first saves the current queue to a new playlist named
    /// `name` and then immediately clears that new playlist, ensuring it exists
    /// but is empty.
    ///
    /// - Parameter name: The name for the new playlist.
    /// - Throws: An error if the underlying command execution fails.
    func createPlaylist(named name: String) async throws {
        try await run(["save \(escape(name))", "playlistclear \(escape(name))"])
    }

    /// Renames a playlist.
    ///
    /// - Parameters:
    ///   - playlist: The `Playlist` object representing the playlist to rename.
    ///   - name: The new name for the playlist.
    /// - Throws: An error if the underlying command execution fails.
    func renamePlaylist(_ playlist: Playlist, to name: String) async throws {
        try await run(["rename \(escape(playlist.name)) \(escape(name))"])
    }

    /// Removes a playlist from the media server.
    ///
    /// - Parameter playlist: The `Playlist` object representing the playlist to
    ///                       remove.
    /// - Throws: An error if the underlying command execution fails.
    func removePlaylist(_ playlist: Playlist) async throws {
        try await run(["rm \(escape(playlist.name))"])
    }

    /// Updates the media server's database.
    ///
    /// This function triggers a database update on the media server, which
    /// causes it to scan the music directory and update its internal
    /// database with any changes.
    ///
    /// - Parameter force: A Boolean value indicating whether to force a rescan
    ///                   (`true`) or perform a standard update (`false`).
    /// - Throws: An error if the underlying command execution fails
    func update(force: Bool = false) async throws {
        if force {
            try await run(["rescan"])
        } else {
            try await run(["update"])
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
                    "Playlist is required for this operation")
            }

            commands = songsToAdd.map {
                "playlistadd \(playlist.name) \(escape($0.url.path))"
            }
        case .database:
            throw ConnectionManagerError.unsupportedOperation(
                "Cannot add songs to the database")
        }

        try await run(commands)
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

        try await run(commands)
    }

    /// Moves a song to a new position within the queue or a playlist.
    ///
    /// - Parameters:
    ///   - song: The `Song` object to move. Must have its `position` property
    ///           set.
    ///   - position: The destination index for the song.
    ///   - source: The source (either `.queue` or a `.playlist`) where the move
    ///             should occur.
    /// - Throws: `ConnectionManagerError.unsupportedOperation` if the source is
    ///           not the queue or a playlist, or if the song is missing
    ///           position info.
    func move(_ song: Song, to position: Int, in source: Source) async throws {
        guard let currentPosition = song.position else {
            throw ConnectionManagerError.unsupportedOperation(
                "Cannot move song without a position")
        }

        switch source {
        case .queue:
            try await run(["move \(currentPosition) \(position)"])
        case .playlist, .favorites:
            guard let playlist = source.playlist else {
                throw ConnectionManagerError.unsupportedOperation(
                    "Playlist is required for this operation")
            }

            try await run(["playlistmove \(escape(playlist.name)) \(currentPosition) \(position)"])
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Only queue and playlist sources are supported for moving media")
        }
    }

    /// Plays a specified media item (Song, Album, or Artist).
    ///
    /// This function handles playback differently based on the media type:
    /// - Song: If the song has an ID, it plays it directly (`playid`).
    /// - Album/Artist: It fetches the list of songs for the item, checks which
    ///                 are not already in the queue, adds them using `addid`,
    ///                 and then plays the first song of the item using its ID.
    ///                 This logic avoids clearing the queue.
    /// - Song without ID: Treated like an album with one song.
    ///
    /// - Parameter media: The `Mediable` object to play.
    /// - Throws: An error if the operation is unsupported for the media type or
    ///           if any underlying commands fail.
    func play(_ media: any Mediable) async throws {
        if let song = media as? Song, let id = song.identifier {
            try await run(["playid \(id)"])
            return
        }

        let songs: [Song]
        switch media {
        case let album as Album:
            songs = try await getSongs(in: album, from: .database)
        case let artist as Artist:
            let lines = try await run(["find \(filter(key: "artist", value: artist.name))"])
            songs = try await parseMediaResponse(lines, as: .song)
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

        try await run(["playid \(id)"])
    }

    /// Sets the pause state of the player.
    ///
    /// - Parameter value: A Boolean value indicating whether to pause (`true`)
    ///                    or resume (`false`) playback.
    /// - Throws: An error if the underlying command execution fails.
    func pause(_ value: Bool) async throws {
        try await run([value ? "pause 1" : "pause 0"])
    }

    /// Play the previous song in the queue.
    ///
    /// - Throws: An error if the underlying command execution fails.
    func previous() async throws {
        try await run(["previous"])
    }

    /// Play the next song in the queue.
    ///
    /// - Throws: An error if the underlying command execution fails.
    func next() async throws {
        try await run(["next"])
    }

    /// Sets the consume mode.
    ///
    /// - Parameter value: A Boolean value indicating whether to enable (`true`)
    ///                    or disable (`false`) consume mode.
    /// - Throws: An error if the underlying command execution fails.
    func consume(_ value: Bool) async throws {
        try await run([value ? "consume 1" : "consume 0"])
    }

    /// Sets the random mode.
    ///
    /// - Parameter value: A Boolean value indicating whether to enable (`true`)
    ///                    or disable (`false`) random mode.
    /// - Throws: An error if the underlying command execution fails.
    func random(_ value: Bool) async throws {
        try await run([value ? "random 1" : "random 0"])
    }

    /// Sets the repeat mode.
    ///
    /// - Parameter value: A Boolean value indicating whether to enable (`true`)
    ///                    or disable (`false`) repeat mode.
    /// - Throws: An error if the underlying command execution fails.
    func `repeat`(_ value: Bool) async throws {
        try await run([value ? "repeat 1" : "repeat 0"])
    }

    /// Seek to a specific position in the currently playing song.
    ///
    /// - Parameter value: The position to seek to, represented as a `Double` in
    ///                    seconds.
    /// - Throws: An error if the underlying command execution fails.
    func seek(_ value: Double) async throws {
        try await run(["seekcur \(value)"])
    }

    /// Sets the volume level.
    ///
    /// - Parameter volume: The volume level to set (0-100).
    /// - Throws: An error if the underlying command execution fails.
    func setVolume(_ volume: Int) async throws {
        try await run(["setvol \(volume)"])
    }
}
