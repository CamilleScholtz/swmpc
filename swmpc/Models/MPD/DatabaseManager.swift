//
//  DatabaseManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

/// Manages the MPD database, handling artists, albums, and song queries.
@Observable final class DatabaseManager {
    /// The state manager, used to indicate when data is being fetched.
    @ObservationIgnored private let state: StateManager

    /// Creates a new database manager.
    ///
    /// - Parameter state: An instance of `StateManager` to report back loading
    ///                    activity for UI updates.
    init(state: StateManager) {
        self.state = state
    }

    /// The collection of currently loaded media items (e.g., albums, artists,
    /// or songs) based on the active `type`.
    private(set) var media: [any Mediable]?

    /// The current type of media being displayed or managed (e.g., albums,
    /// artists).
    private(set) var type: MediaType = .album

    /// The current sort option being used.
    private(set) var sort: SortDescriptor = .default

    /// Sets the media type and/or sort descriptor and fetches corresponding
    /// media from MPD.
    ///
    /// This method only fetches new data if the type or sort has changed. It
    /// uses either the idle connection (more efficient for background updates)
    /// or creates a new command connection based on the `idle` parameter.
    ///
    /// - Parameters:
    ///   - idle: Whether to use the long-lived idle connection (default: true).
    ///           Set to false for immediate user-initiated fetches.
    ///   - type: The media type to fetch (album, artist, song, or playlist).
    ///           If `nil`, retains the current type.
    ///   - sort: The sort descriptor for ordering results.
    ///           If `nil`, retains the current sort.
    /// - Throws: An error if the MPD connection fails or the fetch is
    ///           cancelled.
    func set(idle: Bool = true, type: MediaType? = nil, sort: SortDescriptor?
        = nil)
        async throws
    {
        defer { state.isLoading = false }

        guard type != self.type || sort != self.sort else {
            return
        }

        let newMedia: [any Mediable]? = switch type ?? self.type {
        case .album:
            try await idle
                ? ConnectionManager.idle.getAlbums(sort: sort ?? self.sort)
                : ConnectionManager.command {
                    try await $0.getAlbums(sort: sort ?? self.sort)
                }
        case .artist:
            try await idle
                ? ConnectionManager.idle.getArtists(sort: sort ?? self.sort)
                : ConnectionManager.command {
                    try await $0.getArtists(sort: sort ?? self.sort)
                }
        case .song:
            try await idle
                ? ConnectionManager.idle.getSongs(from: Source.database,
                                                  sort: sort ?? self.sort)
                : ConnectionManager.command {
                    try await $0.getSongs(from: Source.database, sort: sort
                        ?? self.sort)
                }
        case .playlist:
            nil
        }

        try Task.checkCancellation()

        if let type {
            self.type = type
        }
        if let sort {
            self.sort = sort
        }

        media = newMedia
    }

    /// Searches through the locally cached media library on a background
    /// thread.
    ///
    /// This function performs a localized case-insensitive search through the
    /// cached media, matching the query against fields determined by the search
    /// fields.
    ///
    /// - Parameters:
    ///   - query: The search query string to match against the selected fields.
    ///   - fields: The search fields that determine which fields to search.
    /// - Returns: An array of media items matching the search criteria.
    func search(_ query: String, fields: SearchFields) async
        -> [any Mediable]
    {
        guard !query.isEmpty, !fields.isEmpty, let media else {
            return []
        }

        return await Task { @concurrent in
            media.filter { item in
                matches(item: item, query: query, fields: fields.fields)
            }
        }.value
    }

    /// Checks if a media item matches the search query against specified
    /// fields.
    ///
    /// - Parameters:
    ///   - item: The media item to check (Song, Album, or Artist).
    ///   - query: The search query string.
    ///   - fields: Set of field names to search ("title", "artist", "album").
    /// - Returns: `true` if the item matches the query in any of the specified
    ///            fields.
    private nonisolated func matches(item: any Mediable, query: String,
                                     fields: Set<String>) -> Bool
    {
        switch item {
        case let song as Song:
            (fields.contains("title") && (contains(song.title, query) || contains(song.titleSort, query))) ||
                (fields.contains("artist") && (contains(song.artist, query) || contains(song.artistSort, query))) ||
                (fields.contains("album") && (contains(song.album.title, query) || contains(song.album.titleSort, query))) ||
                (fields.contains("genre") && contains(song.genre, query)) ||
                (fields.contains("composer") && contains(song.composer, query)) ||
                (fields.contains("performer") && contains(song.performer, query)) ||
                (fields.contains("conductor") && contains(song.conductor, query)) ||
                (fields.contains("ensemble") && contains(song.ensemble, query)) ||
                (fields.contains("mood") && contains(song.mood, query)) ||
                (fields.contains("comment") && contains(song.comment, query))
        case let album as Album:
            (fields.contains("title") && (contains(album.title, query) || contains(album.titleSort, query))) ||
                (fields.contains("artist") && (contains(album.artist.name, query) || contains(album.artist.nameSort, query)))
        case let artist as Artist:
            fields.contains("artist") && (contains(artist.name, query) || contains(artist.nameSort, query))
        default:
            false
        }
    }

    /// Performs a localized case-insensitive comparison to check if text
    /// contains query.
    ///
    /// - Parameters:
    ///   - text: The optional text to search within.
    ///   - query: The normalized query string.
    /// - Returns: `true` if the text contains the query (diacritic and case-insensitive).
    private nonisolated func contains(_ text: String?, _ query: String) -> Bool {
        guard let text else {
            return false
        }

        let options: String.CompareOptions = [.diacriticInsensitive,
                                              .caseInsensitive]

        return text.folding(options: options, locale: nil)
            .contains(query.folding(options: options, locale: nil))
    }
}
