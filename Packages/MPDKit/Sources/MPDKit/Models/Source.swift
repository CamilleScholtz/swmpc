//
//  Source.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Specifies the source of media items.
public enum Source: Equatable, Hashable, Sendable {
    /// Media items from the MPD database.
    case database
    /// Media items from the current queue.
    case queue
    /// Media items from a specific playlist.
    case playlist(Playlist)
    /// Media items from the favorites playlist.
    case favorites

    /// Returns the playlist if this source represents a playlist.
    public nonisolated var playlist: Playlist? {
        switch self {
        case .database, .queue:
            nil
        case let .playlist(playlist):
            playlist
        case .favorites:
            Playlist(name: "Favorites")
        }
    }

    /// Indicates whether items from this source can be reordered.
    public nonisolated var isReorderable: Bool {
        switch self {
        case .queue, .playlist, .favorites:
            true
        case .database:
            false
        }
    }

    /// Indicates whether items from this source can be sorted.
    public nonisolated var isSortable: Bool {
        switch self {
        case .queue, .playlist, .favorites:
            false
        case .database:
            true
        }
    }

    /// Returns available search fields for the given media type.
    public nonisolated func availableSearchFields(for mediaType: MediaType) ->
        [SearchField]
    {
        switch mediaType {
        case .album:
            [.title, .artist]
        case .artist:
            [.artist]
        case .song:
            [.title, .artist, .genre, .composer, .performer, .conductor,
             .ensemble, .mood, .comment]
        case .playlist:
            []
        }
    }

    /// Returns default search fields for the given media type.
    public nonisolated func defaultSearchFields(for mediaType: MediaType) ->
        SearchFields
    {
        switch mediaType {
        case .album:
            SearchFields(fields: [.title, .artist])
        case .artist:
            SearchFields(fields: [.artist])
        case .song:
            SearchFields(fields: [.title, .artist])
        case .playlist:
            SearchFields.default
        }
    }

    /// Returns the available sort options for the given media type.
    public nonisolated func availableSortOptions(for mediaType: MediaType) ->
        [SortOption]
    {
        switch mediaType {
        case .album:
            [.artist, .album, .modified]
        case .artist:
            [.artist, .modified]
        case .song:
            [.album, .song, .artist, .modified]
        case .playlist:
            []
        }
    }
}
