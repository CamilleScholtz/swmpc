//
//  Song.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Represents a song in the MPD database.
///
/// Songs contain detailed metadata including title, artist, album, duration,
/// disc and track numbers.
public nonisolated struct Song: Mediable {
    /// The unique identifier for the song, which is its file path.
    public nonisolated var id: String {
        file
    }

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
        album: Album,
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
