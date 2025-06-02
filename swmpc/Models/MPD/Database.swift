//
//  Database.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

enum QueueError: Error {
    case invalidType
}

@Observable
final class Database {
    /// The media in the queue. This represent the actual MPD database.
    var internalMedia: [any Mediable] = []

    /// The media in the database. This can be the actual MPD database or the
    /// search results.
    var media: [any Mediable] {
        get {
            results ?? internalMedia
        }
        set {
            internalMedia = newValue
        }
    }

    /// The search results. If this is not `nil`, `media` will return this.
    var results: [any Mediable]?

    /// The type of media in the database. This can be `album`, `artist`,
    /// `song`, or `playlist`.
    var type: MediaType?

    /// The playlists available on the server.
    var playlists: [Playlist]?

    /// The songs in the `Favorites` playlist.
    var favorites: [Song] = []

    /// The date at which the database was last updated.
    var lastUpdated: Date = .now

    /// This asynchronous function sets the media in the database.
    ///
    /// - Parameters:
    ///     - type: The type of media to set.
    ///     - idle: Whether to use the idle connection.
    ///     - force: Whether to force the update, this will update the database
    ///              even if the type is the same as the current one.
    /// - Throws: An error if the media could not be set.
    @MainActor
    func set(using type: MediaType? = nil, idle: Bool = false, force: Bool =
        false) async throws
    {
        defer { lastUpdated = Date() }

        let current = type ?? self.type
        guard force || current != self.type else {
            return
        }

        defer { self.type = current }

        media = switch type {
        case .album:
            try await idle
                ? ConnectionManager.idle.getAlbums(using: .database)
                : ConnectionManager.command().getAlbums(using: .database)
        case .artist:
            try await idle
                ? ConnectionManager.idle.getArtists(using: .database)
                : ConnectionManager.command().getArtists(using: .database)
        case .song, .playlist:
            try await idle
                ? ConnectionManager.idle.getSongs(using: .database)
                : ConnectionManager.command().getSongs(using: .database)
        default:
            throw QueueError.invalidType
        }
    }

    /// This asynchronous function sets the playlists available on the server.
    /// It also sets the songs in the `Favorites` playlist.
    ///
    /// - Note: The `Favorites` playlist is filtered out of the playlists.
    ///
    /// - Throws: An error if the playlists could not be set.
    @MainActor
    func setPlaylists() async throws {
        let allPlaylists = try await ConnectionManager.idle.getPlaylists()

        playlists = allPlaylists.filter { $0.name != "Favorites" }

        guard let favoritePlaylist = allPlaylists.first(where: {
            $0.name == "Favorites"
        }) else {
            return
        }

        favorites = try await ConnectionManager.idle.getSongs(for:
            favoritePlaylist)
    }

    /// This asynchronous function searches for media in the database.
    ///
    /// - Parameters:
    ///     - query: The query to search for.
    ///     - type: The type of media to search for and set.
    /// - Throws: An error if the search could not be performed.
    @MainActor
    func search(for query: String, using type: MediaType? = nil) async throws {
        let current = type ?? self.type
        try await set(using: current)

        results = switch current {
        case .album:
            (internalMedia as! [Album]).filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        case .artist:
            (internalMedia as! [Artist]).filter {
                $0.name.range(of: query, options: .caseInsensitive) != nil
            }
        case .song, .playlist:
            (internalMedia as! [Song]).filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        default:
            throw QueueError.invalidType
        }
    }

    /// This asynchronous function gets for a given media the corresponding
    /// media in the queue of a given type.
    ///
    /// For example, if the current given media is `Song`, and the given type
    /// is `Album`, this will return the `Album` that contains of the given `Song`.
    ///
    /// - Parameters:
    ///     - media: The media to get the corresponding media for.
    ///     - type: The type of media to get.
    /// - Returns: The corresponding media in the queue.
    /// - Throws: An error if the media could not be fetched.
    @MainActor
    func get(for media: any Mediable, using type: MediaType? = nil) async throws
        -> (any Mediable)?
    {
        let current = type ?? self.type
        guard current != .song else {
            return media
        }

        try await set(using: current)

        switch (media, current) {
        case let (song as Song, .album):
            return (internalMedia as? [Album])?.first { album in
                album.artist == song.artist &&
                    album.url.deletingLastPathComponent() == song.url.deletingLastPathComponent()
            }
        case let (song as Song, .artist):
            return (internalMedia as? [Artist])?.first { artist in
                artist.name == song.artist
            }
        case let (album as Album, .artist):
            return (internalMedia as? [Artist])?.first { artist in
                artist.name == album.artist
            }
        case let (artist as Artist, .album):
            return artist.albums?.first
        default:
            throw QueueError.invalidType
        }
    }
}
