//
//  CommandModeCommands.swift
//  MPDKit
//

import Foundation

/// Commands specific to command mode connections.
public extension ConnectionManager where Mode == CommandMode {
    /// Executes a command operation with automatic connection cleanup.
    ///
    /// This method creates a new connection, executes the provided closure with
    /// the connection manager, and ensures the connection is properly
    /// disconnected when the operation completes (whether it succeeds or
    /// throws).
    ///
    /// - Parameter operation: A closure that receives a connected
    ///                        `ConnectionManager<CommandMode>` and performs
    ///                        operations on it.
    /// - Returns: The result of the operation closure.
    /// - Throws: An error if the connection fails or if the operation throws.
    static func command<T: Sendable>(_ operation: @Sendable (ConnectionManager<
        CommandMode,
    >) async throws -> T) async throws -> T {
        let manager = ConnectionManager<CommandMode>()
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
            !existingSongs.contains { $0.file == song.file }
        }

        let commands: [String]
        switch source {
        case .queue:
            commands = songsToAdd.map {
                "add \(escape($0.file))"
            }
        case .playlist, .favorites:
            guard let playlist = source.playlist else {
                throw ConnectionManagerError.unsupportedOperation(
                    "Playlist is required for this operation",
                )
            }

            commands = songsToAdd.map {
                "playlistadd \(playlist.name) \(escape($0.file))"
            }
        case .database:
            throw ConnectionManagerError.unsupportedOperation(
                "Cannot add songs to the database",
            )
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
        let filesToRemove = Set(songs.map(\.file))
        let positions = sourceSongs
            .compactMap { song in
                filesToRemove.contains(song.file) ? song.position : nil
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
                guard let playlist = source.playlist else {
                    continue
                }
                if start == end {
                    commands.append(
                        "playlistdelete \(escape(playlist.name)) \(start)",
                    )
                } else {
                    for pos in stride(from: Int(start), through: Int(end), by:
                        -1)
                    {
                        commands.append(
                            "playlistdelete \(escape(playlist.name)) \(pos)",
                        )
                    }
                }
            default:
                throw ConnectionManagerError.unsupportedOperation(
                    "Only queue and playlist sources are supported for removing songs",
                )
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
                "Cannot move song without a position",
            )
        }

        switch source {
        case .queue:
            try await run(["move \(currentPosition) \(position)"])
        case .playlist, .favorites:
            guard let playlist = source.playlist else {
                throw ConnectionManagerError.unsupportedOperation(
                    "Playlist is required for this operation",
                )
            }

            try await run(["playlistmove \(escape(playlist.name)) \(currentPosition) \(position)"])
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Only queue and playlist sources are supported for moving media",
            )
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
            songs = try parseMediaResponseArray(lines, as: .song)
        case let song as Song:
            songs = [song]
        default:
            throw ConnectionManagerError.unsupportedOperation(
                "Only Album, Artist, and Song types are supported for playback",
            )
        }

        guard !songs.isEmpty else {
            throw ConnectionManagerError.malformedResponse(
                "No songs found for the specified media",
            )
        }

        let queue = try await getSongs(from: .queue)

        var id: UInt32?
        var commands = [String]()

        for (index, song) in songs.enumerated() {
            if let existingSong = queue.first(where: { $0.file == song.file }) {
                if index == 0 {
                    id = existingSong.identifier
                }
            } else {
                commands.append("addid \(escape(song.file))")
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
                "Failed to determine song ID to play",
            )
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

    /// Stops playback.
    ///
    /// - Throws: An error if the underlying command execution fails.
    func stop() async throws {
        try await run(["stop"])
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

    /// Toggles an audio output.
    ///
    /// - Parameter id: The ID of the output to toggle.
    /// - Throws: An error if the underlying command execution fails.
    func toggleOutput(_ output: Output) async throws {
        try await run(["toggleoutput \(output.id)"])
    }
}
