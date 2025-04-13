//
//  Connection.swift
//  swmpc
//
//  Created by Camille Scholtz on 11/04/2025.
//

import SwiftUI

enum ConnectionType {
    case idle
    case artwork
    case command
}

enum Connection: String, CaseIterable, Identifiable {
    case mpd
    // case mock

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mpd:
            return "MPD Connection"
//        case .mock:
//            return "Mock Connection"
        }
    }

    func get(using type: ConnectionType) async throws -> any Connectionable {
        switch self {
        case .mpd:
            switch type {
            case .idle:
                return MPDConnection.idle
            case .artwork:
                return try await MPDConnection.artwork()
            case .command:
                return try await MPDConnection.command()
            }
//        case .mock:
//            return MockConnection
        }
    }
}

enum ConnectionError: Error {
    case invalidMode
}

protocol Connectionable {
    // MARK: - Properties

    /// The version of the MPD server.
    var version: String? { get async }

    // MARK: - Connection Lifecycle

    /// Establishes a connection to the MPD server.
    func connect() async throws

    /// Disconnects from the MPD server and resets internal state.
    func disconnect() async

    // MARK: - Command Execution

    /// Executes one or more commands on the MPD server.
    /// - Parameter commands: An array of command strings to execute.
    /// - Returns: An array of response lines from the server.
    func run(_ commands: [String]) async throws -> [String]

    // MARK: - Shared Commands

    /// Retrieves the current status of the media player.
    /// - Returns: A tuple with information about the player state, random/repeat settings,
    ///            elapsed time, the current playlist (if any), and the currently playing song.
    func getStatusData() async throws -> (
        state: PlayerState?,
        isRandom: Bool?,
        isRepeat: Bool?,
        elapsed: Double?,
        playlist: Playlist?,
        song: Song?
    )

    /// Retrieves all songs from the current queue.
    func getSongs() async throws -> [Song]

    /// Retrieves songs from the queue that match the specified artist.
    func getSongs(for artist: Artist) async throws -> [Song]

    /// Retrieves songs from the queue for the specified album.
    func getSongs(for album: Album) async throws -> [Song]

    /// Retrieves songs from the queue for the specified playlist.
    func getSongs(for playlist: Playlist) async throws -> [Song]

    /// Retrieves all albums from the queue.
    func getAlbums() async throws -> [Album]

    /// Retrieves album artists derived from the queue.
    func getArtists() async throws -> [Artist]

    /// Retrieves all available playlists from the server.
    func getPlaylists() async throws -> [Playlist]
}

// MARK: - Mode-Specific Protocols

/// Protocol for idle-mode connection managers.
protocol IdleConnection: Connectionable {
    /// Waits for an idle event from the server matching the provided mask.
    /// - Parameter mask: An array of `IdleEvent` values specifying which events to listen for.
    /// - Returns: The `IdleEvent` that was triggered.
    func idleForEvents(mask: [IdleEvent]) async throws -> IdleEvent
}

/// Protocol for artwork-mode connection managers.
protocol ArtworkConnection: Connectionable {
    /// Factory method for creating an artwork-mode connection manager.
    static func artwork() async throws -> Self

    /// Retrieves binary artwork data for a given URL.
    /// - Parameter url: The artwork resource URL from the MPD server.
    /// - Returns: The binary data of the artwork.
    func getArtworkData(for url: URL) async throws -> Data
}

/// Protocol for command-mode connection managers.
protocol CommandConnection: Connectionable {
    /// Factory method for creating a command-mode connection manager.
    static func command() async throws -> Self

    // Playlist management

    /// Loads a playlist into the server queue, or if `nil` is provided,
    /// loads songs from the entire music directory.
    func loadPlaylist(_ playlist: Playlist?) async throws

    /// Creates a new playlist with the given name.
    func createPlaylist(named name: String) async throws

    /// Renames an existing playlist.
    func renamePlaylist(_ playlist: Playlist, to name: String) async throws

    /// Removes an existing playlist from the server.
    func removePlaylist(_ playlist: Playlist) async throws

    /// Adds songs to the specified playlist.
    func addToPlaylist(_ playlist: Playlist, songs: [Song]) async throws

    /// Removes songs from the specified playlist.
    func removeFromPlaylist(_ playlist: Playlist, songs: [Song]) async throws

    // Playback control

    /// Triggers a database update on the MPD server.
    func update() async throws

    /// Plays the given playable media (either a Song or an Album).
    func play(_ media: any Playable) async throws

    /// Toggles the pause state (pausing if `true`, resuming if `false`).
    func pause(_ value: Bool) async throws

    /// Plays the previous song in the queue.
    func previous() async throws

    /// Plays the next song in the queue.
    func next() async throws

    /// Enables or disables repeat mode.
    func `repeat`(_ value: Bool) async throws

    /// Enables or disables random playback mode.
    func random(_ value: Bool) async throws

    /// Seeks to a specified position in the current song.
    /// - Parameter value: The target position, expressed as a percentage.
    func seek(_ value: Double) async throws
}
