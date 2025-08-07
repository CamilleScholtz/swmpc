//
//  Enums.swift
//  swmpc
//
//  Created by Camille Scholtz on 10/11/2024.
//

import SFSafeSymbols
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

    /// Returns the available sort options for this media type.
    var availableSortOptions: [SortOption] {
        switch self {
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

    /// Indicates whether items from this source can be moved (reordered).
    nonisolated var isMovable: Bool {
        switch self {
        case .queue, .playlist, .favorites:
            true
        case .database:
            false
        }
    }

    /// Indicates whether items from this source can be sorted.
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
    /// Sort by the last modified date.
    case modified = "Last-Modified"

    /// Returns the localized display label for this sort option.
    var label: LocalizedStringResource {
        switch self {
        case .artist:
            "Artist"
        case .album:
            "Album"
        case .song:
            "Song"
        case .modified:
            "Last Modified"
        }
    }
}

/// Represents the direction of sorting for media items.
enum SortDirection: String {
    /// Sort in ascending order.
    case ascending = ""
    /// Sort in descending order.
    case descending = "-"

    /// Returns the localized display label for this sort direction.
    var label: LocalizedStringResource {
        switch self {
        case .ascending:
            "Ascending"
        case .descending:
            "Descending"
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

/// Represents individual search fields that can be selected.
enum SearchField: String, CaseIterable {
    case title = "Title"
    case artist = "Artist"
    case album = "Album"
    case genre = "Genre"

    /// Returns the localized display label for this search field.
    var label: LocalizedStringResource {
        switch self {
        case .title:
            "Title"
        case .artist:
            "Artist"
        case .album:
            "Album"
        case .genre:
            "Genre"
        }
    }

    /// Returns the SF Symbol icon associated with this search field.
    var symbol: SFSymbol {
        switch self {
        case .title:
            .textformatCharacters
        case .artist:
            .person
        case .album:
            .squareStack
        case .genre:
            .musicNote
        }
    }
}

/// Manages the selected search fields for searching media.
struct SearchFields: Equatable {
    private var selectedFields: Set<SearchField>

    /// Initializes search fields with an optional set of pre-selected fields.
    /// - Parameter fields: The set of search fields to initially select.
    init(fields: Set<SearchField> = []) {
        selectedFields = fields
    }

    /// Creates default search fields based on the media type.
    static func defaultFields(for mediaType: MediaType) -> SearchFields {
        switch mediaType {
        case .album:
            SearchFields(fields: [.title, .artist])
        case .artist:
            SearchFields(fields: [.artist])
        case .song:
            SearchFields(fields: [.title, .artist])
        case .playlist:
            SearchFields(fields: [.title, .artist])
        }
    }

    /// Returns available search fields for the given media type.
    static func availableFields(for mediaType: MediaType) -> [SearchField] {
        switch mediaType {
        case .album:
            [.title, .artist, .genre]
        case .artist:
            [.artist]
        case .song:
            [.title, .artist, .genre]
        case .playlist:
            [.title, .artist, .genre]
        }
    }

    /// Toggles the selection state of a search field.
    /// - Parameter field: The search field to toggle.
    mutating func toggle(_ field: SearchField) {
        if selectedFields.contains(field) {
            selectedFields.remove(field)
        } else {
            selectedFields.insert(field)
        }
    }

    /// Checks if a specific search field is selected.
    /// - Parameter field: The search field to check.
    /// - Returns: `true` if the field is selected, `false` otherwise.
    func contains(_ field: SearchField) -> Bool {
        selectedFields.contains(field)
    }

    /// Indicates whether no search fields are selected.
    var isEmpty: Bool {
        selectedFields.isEmpty
    }

    /// Returns the selected fields as a set of lowercase string values for MPD queries.
    var fields: Set<String> {
        Set(selectedFields.map { $0.rawValue.lowercased() })
    }
}
