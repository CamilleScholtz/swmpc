//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

protocol Mediable: Identifiable, Equatable, Hashable {}

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

    func isIn(_ album: Album) -> Bool {
        self.album == album
    }
}

/// Represents a playlist in the MPD database.
///
/// Playlists are named collections of songs that can be saved and loaded.
struct Playlist: Identifiable, Equatable, Hashable, Codable, Sendable {
    var id: String { name }

    let name: String
}
