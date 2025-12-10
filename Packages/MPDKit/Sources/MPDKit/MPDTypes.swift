//
//  MPDTypes.swift
//  MPDKit
//
//  Core MPD types shared between the main app and widget extension.
//

import SwiftUI

// MARK: - Player State

/// Represents the current playback state of the MPD player.
public enum PlayerState: Sendable {
    /// The player is currently playing music.
    case play
    /// The player is paused.
    case pause
    /// The player is stopped.
    case stop
}

// MARK: - Media Type

/// Represents the different types of media that can be managed by MPD.
public enum MediaType: Sendable {
    /// An album containing multiple songs.
    case album
    /// An artist who has created music.
    case artist
    /// An individual song or track.
    case song
    /// A user-created playlist of songs.
    case playlist
}

// MARK: - Idle Event

/// Represents the different subsystems that MPD monitors for changes.
///
/// These events are used with MPD's idle command to receive notifications.
public enum IdleEvent: String, Sendable {
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

// MARK: - Artwork Getter

/// Specifies the method for retrieving artwork from MPD.
public enum ArtworkGetter: String, Codable, Sendable {
    /// Retrieve artwork from the music library folder structure.
    case library = "albumart"
    /// Retrieve artwork embedded in the audio file.
    case metadata = "readpicture"
}

// MARK: - Sort Types

/// Represents a sort descriptor for media items.
public enum SortOption: String, Sendable {
    /// Sort by album artist.
    case artist = "albumartistsort"
    /// Sort by album title.
    case album = "albumsort"
    /// Sort by song title.
    case song = "titlesort"
    /// Sort by the last modified date.
    case modified = "Last-Modified"

    /// Returns the localized display label for this sort option.
    public var label: LocalizedStringResource {
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
public enum SortDirection: String, Sendable {
    /// Sort in ascending order.
    case ascending = ""
    /// Sort in descending order.
    case descending = "-"

    /// Returns the localized display label for this sort direction.
    public var label: LocalizedStringResource {
        switch self {
        case .ascending:
            "Ascending"
        case .descending:
            "Descending"
        }
    }
}

/// Represents a complete sort descriptor combining a sort option with a
/// direction.
///
/// Used to specify how collections of media items should be sorted. The
/// descriptor can be serialized to and from a string representation for
/// persistence.
public nonisolated struct SortDescriptor: RawRepresentable, Equatable, Hashable,
    Sendable
{
    /// The field or property to sort by.
    public let option: SortOption

    /// The direction of the sort (ascending or descending).
    public let direction: SortDirection

    /// The default sort descriptor, sorting by artist in ascending order.
    public static let `default` = SortDescriptor(option: .artist, direction:
        .ascending)

    /// Creates a sort descriptor with the specified option and direction.
    ///
    /// - Parameters:
    ///   - option: The field to sort by.
    ///   - direction: The sort direction. Defaults to `.ascending`.
    public init(option: SortOption, direction: SortDirection = .ascending) {
        self.option = option
        self.direction = direction
    }

    /// Creates a sort descriptor from its string representation.
    ///
    /// The expected format is "option_direction" where direction is either
    /// "ascending" or "descending". If direction is omitted, defaults to
    /// ascending. Returns the default descriptor if parsing fails.
    ///
    /// - Parameter rawValue: The string representation of the sort descriptor.
    public init(rawValue: String) {
        let components = rawValue.split(separator: "_")
        guard let first = components.first,
              let option = SortOption(rawValue: String(first))
        else {
            self = .default

            return
        }

        self.option = option
        direction = components.count == 2 && components[1] == "descending" ?
            .descending : .ascending
    }

    /// The string representation of this sort descriptor.
    ///
    /// Returns a string in the format "option_direction" for serialization.
    public var rawValue: String {
        "\(option.rawValue)_\(direction == .ascending ? "ascending" : "descending")"
    }
}

// MARK: - Search Types

/// Represents individual search fields that can be selected.
public enum SearchField: String, CaseIterable, Sendable {
    case title = "Title"
    case artist = "Artist"
    case album = "Album"
    case genre = "Genre"
    case composer = "Composer"
    case performer = "Performer"
    case conductor = "Conductor"
    case ensemble = "Ensemble"
    case mood = "Mood"
    case comment = "Comment"

    /// Returns the localized display label for this search field.
    public var label: LocalizedStringResource {
        switch self {
        case .title:
            "Title"
        case .artist:
            "Artist"
        case .album:
            "Album"
        case .genre:
            "Genre"
        case .composer:
            "Composer"
        case .performer:
            "Performer"
        case .conductor:
            "Conductor"
        case .ensemble:
            "Ensemble"
        case .mood:
            "Mood"
        case .comment:
            "Comment"
        }
    }
}

/// Manages the selected search fields for searching media.
public nonisolated struct SearchFields: Equatable, RawRepresentable, Sendable {
    private var selectedFields: Set<SearchField>

    /// The default search fields (empty set).
    public static let `default` = SearchFields()

    /// Initializes search fields with an optional set of pre-selected fields.
    /// - Parameter fields: The set of search fields to initially select.
    public init(fields: Set<SearchField> = []) {
        selectedFields = fields
    }

    /// Creates search fields from a string representation.
    /// - Parameter rawValue: Comma-separated list of search field raw values.
    public init(rawValue: String) {
        if rawValue.isEmpty {
            selectedFields = []
        } else {
            selectedFields = Set(
                rawValue.split(separator: ",")
                    .compactMap { SearchField(rawValue: String($0)) }
            )
        }
    }

    /// The string representation of selected fields for persistence.
    public var rawValue: String {
        selectedFields.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// Toggles the selection state of a search field.
    /// - Parameter field: The search field to toggle.
    public mutating func toggle(_ field: SearchField) {
        if selectedFields.contains(field) {
            selectedFields.remove(field)
        } else {
            selectedFields.insert(field)
        }
    }

    /// Checks if a specific search field is selected.
    /// - Parameter field: The search field to check.
    /// - Returns: `true` if the field is selected, `false` otherwise.
    public func contains(_ field: SearchField) -> Bool {
        selectedFields.contains(field)
    }

    /// Indicates whether no search fields are selected.
    public var isEmpty: Bool {
        selectedFields.isEmpty
    }

    /// Returns the selected fields as a set of lowercase string values for
    /// MPD queries.
    public var fields: Set<String> {
        Set(selectedFields.map { $0.rawValue.lowercased() })
    }
}

// MARK: - Playlist

/// Represents a playlist in the MPD database.
///
/// Playlists are named collections of songs that can be saved, loaded, and
/// managed through the MPD server. They are identified by their unique name.
public nonisolated struct Playlist: Identifiable, Equatable, Hashable, Codable,
    Sendable
{
    /// The unique identifier for the playlist, which is its name.
    public nonisolated var id: String { name }

    /// The name of the playlist.
    public let name: String

    /// Creates a new playlist with the given name.
    /// - Parameter name: The name of the playlist.
    public init(name: String) {
        self.name = name
    }
}

// MARK: - Source

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

// MARK: - Server

/// Represents a saved MPD server configuration.
public nonisolated struct Server: Identifiable, Hashable, Sendable, Codable {
    public var id = UUID()

    public var name = ""
    public var host = "localhost"
    public var port = 6600
    public var password = ""
    public var artworkGetter = ArtworkGetter.library

    /// Display name for the server, falling back to host if name is empty.
    public var displayName: String {
        name.isEmpty ? host : name
    }

    /// Creates a new server configuration.
    public init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "localhost",
        port: Int = 6600,
        password: String = "",
        artworkGetter: ArtworkGetter = .library
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.password = password
        self.artworkGetter = artworkGetter
    }
}

// MARK: - Media Types

/// A protocol that defines the base requirements for all media items in the MPD
/// system.
///
/// Types conforming to `Mediable` represent various media entities (artists,
/// albums, songs) that can be stored, compared, and transmitted safely across
/// actor boundaries.
public protocol Mediable: Identifiable, Equatable, Codable, Hashable, Sendable {
    /// Returns a unique identifier for the media item.
    nonisolated var id: String { get }

    /// The file path of the media item in the MPD database.
    var file: String { get }
}

public extension Mediable {
    /// Checks if two media items are equal based on their identifiers.
    ///
    /// - Parameters:
    ///   - lhs: The first media item.
    ///   - rhs: The second media item.
    /// - Returns: `true` if the identifiers match, `false` otherwise.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    /// Generates a hash value for the media item based on its identifier.
    ///
    /// - Parameter hasher: The hasher to use for generating the hash value.
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// A container for artwork image data with equality based on content hash.
///
/// `Artwork` wraps a platform-specific image along with a hash of the original
/// image data. This allows efficient equality comparisons without re-encoding
/// the image, and ensures that identical artwork from different sources
/// (e.g., different songs from the same album) are considered equal.
public nonisolated struct Artwork: Equatable, Sendable {
    /// The platform-specific image.
    #if canImport(UIKit)
        public let image: UIImage?
    #elseif canImport(AppKit)
        public let image: NSImage?
    #endif

    // XXX: Use `file` if this ever gets added to MPD's protocol.
    // See: https://github.com/MusicPlayerDaemon/MPD/issues/2397
    /// A hash of the original image data, used for equality comparisons.
    public let hash: Int

    /// Creates a new artwork container.
    /// - Parameters:
    ///   - image: The platform-specific image.
    ///   - hash: A hash of the original image data.
    #if canImport(UIKit)
        public init(image: UIImage?, hash: Int) {
            self.image = image
            self.hash = hash
        }

    #elseif canImport(AppKit)
        public init(image: NSImage?, hash: Int) {
            self.image = image
            self.hash = hash
        }
    #endif

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hash == rhs.hash
    }
}

/// Represents an artist in the MPD database.
///
/// Artists are identified by their name and can have multiple associated
/// albums.
public nonisolated struct Artist: Mediable {
    /// The unique identifier for the artist, which is the artist's name.
    public nonisolated var id: String { name }

    /// The file path of the artist in the MPD database.
    public let file: String

    /// The name of the artist.
    public let name: String

    /// The sort name for the artist (used for sorting/searching, often contains
    /// romanized versions of non-Latin names).
    public let nameSort: String?

    /// Creates a new artist.
    /// - Parameters:
    ///   - file: The file path in the MPD database.
    ///   - name: The artist's name.
    ///   - nameSort: The sort name for the artist.
    public init(file: String, name: String, nameSort: String?) {
        self.file = file
        self.name = name
        self.nameSort = nameSort
    }
}

/// Represents an album in the MPD database.
///
/// Albums are identified by their artist-title combination and can contain
/// multiple songs.
public nonisolated struct Album: Mediable {
    /// The unique identifier for the album, which is the artist-title
    /// description.
    public nonisolated var id: String { description }

    /// The file path of the album in the MPD database.
    public let file: String

    /// The title of the album.
    public let title: String

    /// The sort name for the album title (used for sorting/searching, often
    /// contains romanized versions of non-Latin names).
    public let titleSort: String?

    /// The artist who created this album.
    public let artist: Artist

    /// A human-readable description combining artist name and album title.
    public nonisolated var description: String {
        "\(artist.name) - \(title)"
    }

    /// Creates a new album.
    /// - Parameters:
    ///   - file: The file path in the MPD database.
    ///   - title: The album title.
    ///   - titleSort: The sort name for the title.
    ///   - artist: The artist who created this album.
    public init(file: String, title: String, titleSort: String?, artist:
        Artist)
    {
        self.file = file
        self.title = title
        self.titleSort = titleSort
        self.artist = artist
    }
}

/// Represents a song in the MPD database.
///
/// Songs contain detailed metadata including title, artist, album, duration,
/// disc and track numbers.
public nonisolated struct Song: Mediable {
    /// The unique identifier for the song, which is its file path.
    public nonisolated var id: String { file }

    /// The file path of the song in the MPD database.
    public let file: String

    /// The MPD queue identifier for this song, if it's in the queue.
    public let identifier: UInt32?

    /// The position of this song in the MPD queue, if applicable.
    public let position: UInt32?

    /// The name of the artist performing this song.
    public let artist: String

    /// The sort name for the artist (used for sorting/searching, often contains
    /// romanized versions of non-Latin names).
    public let artistSort: String?

    /// The title of the song.
    public let title: String

    /// The sort name for the title (used for sorting/searching, often contains
    /// romanized versions of non-Latin names).
    public let titleSort: String?

    /// The duration of the song in seconds.
    public let duration: Double

    /// The disc number for multi-disc albums.
    public let disc: Int

    /// The track number within the disc.
    public let track: Int

    /// The genre of the song.
    public let genre: String?

    /// The composer of the song.
    public let composer: String?

    /// The performer of the song.
    public let performer: String?

    /// The conductor of the song.
    public let conductor: String?

    /// The ensemble performing the song.
    public let ensemble: String?

    /// The mood of the song.
    public let mood: String?

    /// Additional comments about the song.
    public let comment: String?

    /// The album this song belongs to.
    public let album: Album

    /// A human-readable description combining artist name and song title.
    public nonisolated var description: String {
        "\(artist) - \(title)"
    }

    /// Creates a new song.
    public init(
        file: String,
        identifier: UInt32?,
        position: UInt32?,
        artist: String,
        artistSort: String?,
        title: String,
        titleSort: String?,
        duration: Double,
        disc: Int,
        track: Int,
        genre: String?,
        composer: String?,
        performer: String?,
        conductor: String?,
        ensemble: String?,
        mood: String?,
        comment: String?,
        album: Album
    ) {
        self.file = file
        self.identifier = identifier
        self.position = position
        self.artist = artist
        self.artistSort = artistSort
        self.title = title
        self.titleSort = titleSort
        self.duration = duration
        self.disc = disc
        self.track = track
        self.genre = genre
        self.composer = composer
        self.performer = performer
        self.conductor = conductor
        self.ensemble = ensemble
        self.mood = mood
        self.comment = comment
        self.album = album
    }

    /// Checks if this song is in a specific album.
    ///
    /// - Parameter album: The album to check against.
    /// - Returns: `true` if the song belongs to the album, `false` otherwise.
    public func isIn(_ album: Album) -> Bool {
        self.album == album
    }

    /// Checks if this song is by a specific artist.
    ///
    /// - Parameter artist: The artist to check against.
    /// - Returns: `true` if the song is by the artist, `false` otherwise.
    public func isBy(_ artist: Artist) -> Bool {
        album.artist == artist
    }
}
