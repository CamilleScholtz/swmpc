//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

protocol Mediable: Identifiable, Equatable, Hashable {
    /// Returns a unique identifier for the media item.
    var id: String { get }
}

extension Mediable {
    /// Checks if two media items are equal based on their identifiers.
    ///
    /// - Parameters:
    ///   - lhs: The first media item.
    ///   - rhs: The second media item.
    /// - Returns: `true` if the identifiers match, `false` otherwise.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    /// Generates a hash value for the media item based on its identifier.
    ///
    /// - Parameter hasher: The hasher to use for generating the hash value.
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

protocol Artworkable {
    @MainActor
    func artwork() async throws -> PlatformImage?
}

extension Artworkable where Self: Mediable {
    /// Fetches the artwork for this media item from the MPD server.
    ///
    /// - Note: Songs are not cached to save memory, while albums and artists
    /// are cached.
    ///
    /// - Returns: A platform-specific image if artwork is available, or `nil`
    ///           if no artwork is found.
    /// - Throws: An error if the artwork retrieval fails.
    @MainActor
    func artwork() async throws -> PlatformImage? {
        let url: URL?
        let shouldCache: Bool

        switch self {
        case let song as Song:
            url = song.url
            shouldCache = false
        case let album as Album:
            url = try await album.getURL()
            shouldCache = true
        default:
            return nil
        }

        guard let url else {
            throw ViewError.missingData
        }

        let data = try await ArtworkManager.shared.get(for: url, shouldCache: shouldCache)

        return PlatformImage(data: data)
    }
}

/// Represents an artist in the MPD database.
struct Artist: Mediable {
    var id: String { name }

    let name: String

    func getAlbums() async throws -> [Album] {
        try await ConnectionManager.command().getAlbums(by: self, from: .database)
    }
}

/// Represents an album in the MPD database.
struct Album: Mediable, Artworkable {
    var id: String { description }

    let title: String

    let artist: Artist

    var description: String {
        "\(artist.name) - \(title)"
    }

    /// Fetches all songs in this album.
    ///
    /// - Returns: An array of Song objects belonging to this album.
    /// - Throws: An error if the command execution fails.
    func getSongs() async throws -> [Song] {
        try await ConnectionManager.command().getSongs(in: self, from: .database)
    }

    /// Fetches the URL of the first song in this album.
    ///
    /// - Returns: The URL of the first song in this album.
    /// - Throws: An error if the command execution fails or no songs are found.
    func getURL() async throws -> URL {
        try await ConnectionManager.command().getURL(of: self)
    }
}

/// Represents a song in the MPD database.
///
/// Songs contain detailed metadata including title, artist, album, duration,
/// and more.
struct Song: Mediable, Artworkable {
    var id: String { url.absoluteString }

    let identifier: UInt32?
    let position: UInt32?
    let url: URL

    let artist: String
    let title: String
    let duration: Double

    let disc: Int
    let track: Int

    let album: Album

    var description: String {
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
}

/// Represents a playlist in the MPD database.
///
/// Playlists are named collections of songs that can be saved and loaded.
struct Playlist: Identifiable, Equatable, Hashable, Codable, Sendable {
    var id: String { name }

    let name: String
}
