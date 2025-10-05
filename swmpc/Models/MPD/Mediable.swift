//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

/// A protocol that defines the base requirements for all media items in the MPD system.
///
/// Types conforming to `Mediable` represent various media entities (artists,
/// albums, songs) that can be stored, compared, and transmitted safely across
/// actor boundaries.
protocol Mediable: Identifiable, Equatable, Codable, Hashable, Sendable {
    /// Returns a unique identifier for the media item.
    nonisolated var id: String { get }

    /// The file path of the media item in the MPD database.
    var file: String { get }
}

extension Mediable {
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

/// A protocol for media items that can have associated artwork.
///
/// Types conforming to `Artworkable` can fetch and optionally cache artwork
/// images from the MPD server.
protocol Artworkable {
    /// Determines if the fetched artwork should be cached.
    ///
    /// Albums and artists typically return `true` to cache artwork for
    /// performance, while songs return `false` to save memory.
    var shouldCacheArtwork: Bool { get }

    /// Fetches the artwork image for this media item.
    ///
    /// - Returns: A platform-specific image if artwork is available, or `nil`
    ///            if no artwork is found.
    /// - Throws: An error if the artwork retrieval fails.
    func artwork() async throws -> PlatformImage?
}

extension Artworkable where Self: Mediable {
    /// Default implementation that fetches artwork from the MPD server using
    /// the media item's file.
    ///
    /// This implementation uses the `ArtworkManager` to retrieve artwork and
    /// respects the `shouldCacheArtwork` property to determine caching
    /// behavior.
    ///
    /// - Returns: A platform-specific image if artwork is available, or `nil`
    ///            if no artwork is found.
    /// - Throws: An error if the artwork retrieval fails.
    func artwork() async throws -> PlatformImage? {
        let data = try await ArtworkManager.shared.get(
            for: file,
            shouldCache: shouldCacheArtwork,
        )

        return PlatformImage(data: data)
    }
}

/// Represents an artist in the MPD database.
///
/// Artists are identified by their name and can have multiple associated
/// albums.
nonisolated struct Artist: Mediable {
    /// The unique identifier for the artist, which is the artist's name.
    nonisolated var id: String { name }

    /// The file path of the artist in the MPD database.
    let file: String

    /// The name of the artist.
    let name: String

    /// Fetches all albums by this artist from the MPD database.
    ///
    /// - Returns: An array of `Album` objects associated with this artist.
    /// - Throws: An error if the database query fails.
    func getAlbums() async throws -> [Album] {
        try await ConnectionManager.command {
            try await $0.getAlbums(by: self, from: .database)
        }
    }
}

/// Represents an album in the MPD database.
///
/// Albums are identified by their artist-title combination and can contain
/// multiple songs.
nonisolated struct Album: Mediable, Artworkable {
    /// The unique identifier for the album, which is the artist-title
    /// description.
    nonisolated var id: String { description }

    /// The file path of the album in the MPD database.
    let file: String

    /// The title of the album.
    let title: String

    /// The artist who created this album.
    let artist: Artist

    /// A human-readable description combining artist name and album title.
    nonisolated var description: String {
        "\(artist.name) - \(title)"
    }

    /// Fetches all songs in this album from the MPD database.
    ///
    /// - Returns: An array of `Song` objects belonging to this album.
    /// - Throws: An error if the database query fails.
    func getSongs() async throws -> [Song] {
        try await ConnectionManager.command {
            try await $0.getSongs(in: self, from: .database)
        }
    }

    /// Albums cache their artwork for performance optimization.
    var shouldCacheArtwork: Bool { true }
}

/// Represents a song in the MPD database.
///
/// Songs contain detailed metadata including title, artist, album, duration,
/// disc and track numbers.
nonisolated struct Song: Mediable, Artworkable {
    /// The unique identifier for the song, which is its file path.
    nonisolated var id: String { file }

    /// The file path of the song in the MPD database.
    let file: String

    /// The MPD queue identifier for this song, if it's in the queue.
    let identifier: UInt32?

    /// The position of this song in the MPD queue, if applicable.
    let position: UInt32?

    /// The name of the artist performing this song.
    let artist: String

    /// The title of the song.
    let title: String

    /// The duration of the song in seconds.
    let duration: Double

    /// The disc number for multi-disc albums.
    let disc: Int

    /// The track number within the disc.
    let track: Int

    /// The genre of the song.
    let genre: String?

    /// The composer of the song.
    let composer: String?

    /// The performer of the song.
    let performer: String?

    /// The conductor of the song.
    let conductor: String?

    /// The ensemble performing the song.
    let ensemble: String?

    /// The mood of the song.
    let mood: String?

    /// Additional comments about the song.
    let comment: String?

    /// The album this song belongs to.
    let album: Album

    /// A human-readable description combining artist name and song title.
    nonisolated var description: String {
        "\(artist) - \(title)"
    }

    /// Checks if this song is in a specific album.
    ///
    /// - Parameter album: The album to check against.
    /// - Returns: `true` if the song belongs to the album, `false` otherwise.
    func isIn(_ album: Album) -> Bool {
        self.album == album
    }

    /// Checks if this song is by a specific artist.
    ///
    /// - Parameter artist: The artist to check against.
    /// - Returns: `true` if the song is by the artist, `false` otherwise.
    func isBy(_ artist: Artist) -> Bool {
        album.artist == artist
    }

    /// Songs don't cache their artwork as the chance we play or view the same
    /// song again is low.
    var shouldCacheArtwork: Bool { false }
}

/// Represents a playlist in the MPD database.
///
/// Playlists are named collections of songs that can be saved, loaded, and
/// managed through the MPD server. They are identified by their unique name.
nonisolated struct Playlist: Identifiable, Equatable, Hashable, Codable,
    Sendable
{
    /// The unique identifier for the playlist, which is its name.
    nonisolated var id: String { name }

    /// The name of the playlist.
    let name: String
}
