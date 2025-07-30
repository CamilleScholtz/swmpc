//
//  Enums.swift
//  swmpc
//
//  Created by Camille Scholtz on 10/11/2024.
//

import SwiftUI

/// Represents the current playback state of the MPD player.
enum PlayerState {
    /// The player is currently playing music.
    case play
    /// The player is paused.
    case pause
    /// The player is stopped.
    case stop
}

/// Represents the different types of media that can be managed by MPD.
enum MediaType {
    /// An album containing multiple songs.
    case album
    /// An artist who has created music.
    case artist
    /// An individual song or track.
    case song
    /// A user-created playlist of songs.
    case playlist

    /// Returns the default search fields for this media type.
    var defaultSearchFields: Set<CategoryView.SearchField> {
        switch self {
        case .album:
            [.title, .artist]
        case .artist:
            [.artist]
        case .song:
            [.title, .artist]
        case .playlist:
            [.title, .artist]
        }
    }

    /// Returns the available sort options for this media type.
    var availableSortOptions: [SortOption] {
        switch self {
        case .album:
            [.artist, .album]
        case .artist:
            [.artist]
        case .song:
            [.album, .song, .artist]
        case .playlist:
            []
        }
    }
}

/// Specifies the source of media items.
enum Source: Equatable, Hashable {
    /// Media items from the MPD database.
    case database
    /// Media items from the current queue.
    case queue
    /// Media items from a specific playlist.
    case playlist(Playlist)
    /// Media items from the favorites playlist.
    case favorites

    /// Returns the playlist if this source represents a playlist.
    nonisolated var playlist: Playlist? {
        switch self {
        case .database, .queue:
            nil
        case let .playlist(playlist):
            playlist
        case .favorites:
            Playlist(name: "Favorites")
        }
    }

    nonisolated var isMovable: Bool {
        switch self {
        case .queue, .playlist, .favorites:
            true
        case .database:
            false
        }
    }

    nonisolated var isSortable: Bool {
        switch self {
        case .queue, .playlist, .favorites:
            false
        case .database:
            true
        }
    }
}

/// Represents the different subsystems that MPD monitors for changes.
///
/// These events are used with MPD's idle command to receive notifications.
enum IdleEvent: String {
    /// The music database has been updated.
    case database
    /// Stored playlists have been modified.
    case playlists = "stored_playlist"
    /// The current queue has changed.
    case queue = "playlist"
    /// Player options (repeat, random, etc.) have changed.
    case options
    /// The player state (play, pause, stop) or current song has changed.
    case player
    /// The mixer volume has changed.
    case mixer
}

/// Represents a sort descriptor for media items.
enum SortOption: String {
    /// Sort by album artist.
    case artist = "albumartistsort"
    /// Sort by album title.
    case album = "albumsort"
    /// Sort by song title.
    case song = "titlesort"

    var label: String {
        switch self {
        case .artist:
            "Artist"
        case .album:
            "Album"
        case .song:
            "Song"
        }
    }
}

/// Represents the direction of sorting for media items.
enum SortDirection: String {
    /// Sort in ascending order.
    case ascending = ""
    /// Sort in descending order.
    case descending = "-"

    var label: String {
        switch self {
        case .ascending:
            "Ascending"
        case .descending:
            "Descending"
        }
    }

    /// Helper to apply the sort direction to a ComparisonResult.
    nonisolated func isOrderedBefore(_ result: ComparisonResult) -> Bool {
        switch self {
        case .ascending:
            return result == .orderedAscending
        case .descending:
            return result == .orderedDescending
        }
    }
}

/// Specifies the method for retrieving artwork from MPD.
enum ArtworkGetter: String {
    /// Retrieve artwork from the music library folder structure.
    case library = "albumart"
    /// Retrieve artwork embedded in the audio file.
    case embedded = "readpicture"
}
