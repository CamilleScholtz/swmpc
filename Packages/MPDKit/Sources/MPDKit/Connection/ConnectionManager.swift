//
//  ConnectionManager.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import DequeModule
import Foundation
import Network

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
public actor ConnectionManager<Mode: ConnectionMode> {
    /// The underlying network connection to the MPD server.
    private var connection: NetworkConnection<TCP>?

    /// Buffer for accumulating incoming data from the network connection.
    private var buffer = Deque<UInt8>()

    /// The version of the MPD server obtained during connection handshake.
    public private(set) var version: String?

    /// Creates a new connection manager.
    public init() {}

    /// Establishes a TCP connection to the MPD server.
    ///
    /// This asynchronous function sets up a new network connection using
    /// `NetworkConnection` with TCP options configured for no-delay.
    ///
    /// - Parameter onStateUpdate: Optional closure called when connection state
    ///                            changes. Receives the connection and the new
    ///                            state.
    /// - Throws: `ConnectionManagerError.invalidPort` if the port is
    ///           invalid, `ConnectionManagerError.connectionSetupFailed` if the
    ///           connection cannot be created, the connection fails to become
    ///           ready, or the expected server greeting is not received,
    ///           `ConnectionManagerError.unsupportedServerVersion` if the
    ///           server version is not supported.
    public func connect(onStateUpdate: (@Sendable (NetworkConnection<TCP>,
                                                   NetworkConnection<TCP>.State)
            -> Void)? = nil) async throws
    {
        guard connection == nil else {
            return
        }

        guard let server = ConnectionConfiguration.server else {
            throw ConnectionManagerError.invalidHost
        }

        let host = server.host
        guard !host.isEmpty else {
            throw ConnectionManagerError.invalidHost
        }

        let port = server.port
        guard port > 0, port <= 65535 else {
            throw ConnectionManagerError.invalidPort
        }

        connection = NetworkConnection(to: .hostPort(host: NWEndpoint.Host(
            host,
        ), port: NWEndpoint.Port(integerLiteral: UInt16(port)))) {
            TCP()
                .noDelay(true)
                .connectionTimeout(3)
        }

        connection?.onStateUpdate { [weak self] connection, state in
            Task {
                switch state {
                case .failed:
                    await self?.disconnect()
                case let .waiting(details):
                    if case let .posix(code) = details, code == .ECONNREFUSED {
                        await self?.disconnect()
                    }
                default:
                    break
                }
            }

            onStateUpdate?(connection, state)
        }

        let lines = try await readUntilOK()
        guard lines.contains(where: { $0.hasPrefix("OK MPD") }) else {
            throw ConnectionManagerError.connectionFailure(
                "Missing OK MPD line from server greeting",
            )
        }

        version = lines.first?.split(separator: " ").last.map(String.init)
        try ensureVersionSupported()
        try await ensureAuthentication()
    }

    /// Disconnects from the current network connection and clears internal
    /// data.
    ///
    /// Cancels any active connection, sets the connection to `nil`, removes all
    /// buffered data, and resets the server version. This method should be
    /// called to cleanly terminate the connection.
    public func disconnect() {
        connection = nil
        version = nil

        buffer.removeAll(keepingCapacity: false)
    }

    /// Ensures that the current network connection is available.
    ///
    /// - Throws: `ConnectionManagerError.connectionUnexpectedClosure` if there
    ///           is no active connection.
    /// - Returns: A ready-to-use `NetworkConnection` instance.
    @discardableResult
    public func ensureConnection() throws -> NetworkConnection<TCP> {
        guard let connection else {
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
    public func ensureVersionSupported() throws {
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
    public func ensureAuthentication() async throws {
        guard let password = ConnectionConfiguration.server?.password,
              !password.isEmpty
        else {
            return
        }

        try await run(["password", password])
    }

    /// Sends a ping command to the server.
    ///
    /// - Throws: An error if the command fails.
    public func ping() async throws {
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
    public func run(_ commands: [String]) async throws -> [String] {
        var list = commands

        if list.count > 1 {
            list.insert("command_list_begin", at: 0)
            list.append("command_list_end")
        }

        try await writeLine(list.joined(separator: "\n"))

        return try await readUntilOK()
    }

    // MARK: - Writing

    /// Asynchronously writes a single line to the network connection.
    ///
    /// This function ensures that the connection is in a ready state, then
    /// appends a newline character to the provided string, converts it to UTF-8
    /// encoded data, and sends it over the connection. NetworkConnection's send
    /// method is async, so we can await it directly.
    ///
    /// - Parameter line: The string to be sent over the connection.
    /// - Throws: An error if the connection is not ready or if the send
    ///           operation encounters an error.
    func writeLine(_ line: String) async throws {
        let connection = try ensureConnection()

        guard let data = (line + "\n").data(using: .utf8) else {
            throw ConnectionManagerError.protocolViolation(
                "Failed to encode command to UTF-8.",
            )
        }

        try await connection.send(data)
    }

    /// Escapes a given string for safe inclusion in MPD commands.
    ///
    /// This function escapes special characters in a string, such as
    /// backslashes and quotes, and optionally encloses the string in a quote
    /// character.
    ///
    /// - Parameters:
    ///   - string: The string to be escaped.
    ///   - quote: An optional quote character to enclose the escaped string.
    ///            Defaults to `"` if not provided.
    /// - Returns: A new string where special characters have been escaped and,
    ///            if a quote is provided, the string is enclosed by it.
    nonisolated func escape(_ string: String, quote: String? = "\"")
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
    nonisolated func filter(key: String, value: String, comparator:
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
    func readLine() async throws -> String? {
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
    /// internal buffer. If the buffer does not contain enough data, it fetches
    /// additional data from the connection using optimized receive calls.
    /// The function continues reading until the specified number of bytes have
    /// been collected.
    ///
    /// - Parameter length: The total number of bytes to read.
    /// - Returns: A `Data` object containing exactly `length` bytes.
    /// - Throws: An error if receiving additional data fails.
    func readFixedLengthData(_ length: Int) async throws -> Data {
        guard length >= 0 else {
            throw ConnectionManagerError.malformedResponse(
                "Invalid data length requested: \(length)",
            )
        }

        guard length > 0 else {
            return Data()
        }

        while buffer.count < length {
            try await receiveDataChunk(remaining: length - buffer.count)
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
                "Failed to decode line from buffer (invalid UTF-8)",
            )
        }

        return string
    }

    /// Asynchronously receives a chunk of data from the network connection.
    ///
    /// This function first ensures that the connection is ready. It then
    /// initiates an asynchronous receive operation using NetworkConnection's
    /// async receive method. Uses the mode's buffer size to optimize for
    /// different connection types.
    ///
    /// - Parameter remaining: Optional number of bytes we still need. If
    ///                        provided and less than or equal to the buffer
    ///                        size, we'll try to receive exactly that amount
    ///                        for efficiency.
    /// - Throws: An error if the connection is not ready or if the receive
    ///           operation encounters an error.
    private func receiveDataChunk(remaining: Int? = nil) async throws {
        let connection = try ensureConnection()

        let chunk: Data = if let remaining, remaining <= Mode.bufferSize {
            try await connection.receive(atLeast: 1, atMost:
                remaining).content
        } else {
            try await connection.receive(atLeast: 1, atMost:
                Mode.bufferSize).content
        }

        if chunk.isEmpty {
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
    nonisolated func chunkLines(_ lines: [String], startingWith prefix:
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
    func readUntil(_ condition: @escaping (String) -> Bool) async throws
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
    func readUntilOK() async throws -> [String] {
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
    func parseLine(_ line: String) throws -> (String, String) {
        let parts = line.split(separator: ":", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        guard parts.count == 2 else {
            throw ConnectionManagerError.malformedResponse(
                "Line does not contain exactly one colon",
            )
        }

        return (parts[0].lowercased(), parts[1])
    }

    /// A private helper to safely cast a value to a generic type `T`.
    ///
    /// - Parameter value: The value to be cast.
    /// - Returns: The value cast to type `T`.
    /// - Throws: `ConnectionManagerError.malformedResponse` if the cast fails.
    private func castResult<T>(_ value: some Any) throws -> T {
        guard let result = value as? T else {
            throw ConnectionManagerError.malformedResponse(
                "Type mismatch: expected \(T.self) but created \(type(of: value))",
            )
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
    func parseMediaResponse<T>(_ lines: [String], as type:
        MediaType, index: Int? = nil) throws -> T
    {
        var fields: [String: String] = [:]
        for line in lines where line != "OK" {
            let (key, value) = try parseLine(line)
            fields[key] = value
        }

        guard let file = fields["file"] else {
            throw ConnectionManagerError.malformedResponse(
                "Missing or invalid file field",
            )
        }

        let artistName = fields["albumartist"] ?? fields["artist"]
            ?? "Unknown Artist"

        switch type {
        case .song:
            let artist: String
            let title: String

            if let name = fields["name"], fields["artist"] == nil,
               fields["title"] == nil
            {
                if let separator = name.range(of: " - ") {
                    artist = String(name[..<separator.lowerBound])
                    title = String(name[separator.upperBound...])
                } else {
                    artist = "Unknown Artist"
                    title = name
                }
            } else {
                artist = fields["artist"] ?? "Unknown Artist"
                title = fields["title"] ?? "Unknown Title"
            }

            let song = Song(
                file: file,
                identifier: fields["id"].flatMap { UInt32($0) },
                position: fields["pos"].flatMap { UInt32($0) }
                    ?? index.map { UInt32($0) },
                artist: artist,
                artistSort: fields["artistsort"],
                title: title,
                titleSort: fields["titlesort"],
                duration: fields["duration"].flatMap { Double($0) } ?? 0,
                disc: fields["disc"].flatMap { Int($0) } ?? 1,
                track: fields["track"].flatMap { Int($0) } ?? 1,
                genre: fields["genre"],
                composer: fields["composer"],
                performer: fields["performer"],
                conductor: fields["conductor"],
                ensemble: fields["ensemble"],
                mood: fields["mood"],
                comment: fields["comment"],
                album: Album(
                    file: file,
                    title: fields["album"] ?? "Unknown Album",
                    titleSort: fields["albumsort"],
                    artist: Artist(
                        file: file,
                        name: artistName,
                        nameSort: fields["albumartistsort"],
                    ),
                ),
            )

            return try castResult(song)
        case .album:
            let album = Album(
                file: file,
                title: fields["album"] ?? "Unknown Album",
                titleSort: fields["albumsort"],
                artist: Artist(
                    file: file,
                    name: artistName,
                    nameSort: fields["albumartistsort"],
                ),
            )

            return try castResult(album)
        case .artist:
            let artist = Artist(
                file: file,
                name: artistName,
                nameSort: fields["albumartistsort"],
            )

            return try castResult(artist)
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Unsupported media type: \(type)",
            )
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
    func parseMediaResponseArray<T>(_ lines: [String],
                                    as type: MediaType,
                                    index: Bool = false)
        throws -> [T]
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
