//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

protocol Mediable: Identifiable, Equatable, Codable, Hashable, Sendable {
    /// Returns a unique identifier for the media item.
    nonisolated var id: String { get }

    /// Returns the location of the media item.
    var url: URL { get }
}

/// A protocol that enables types to be searchable based on different fields.
protocol Searchable {
    /// Returns the value for a specific search field, or nil if the field doesn't apply.
    func search(for field: SearchManager.SearchField) -> String?
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

protocol Artworkable {
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
    func artwork() async throws -> PlatformImage? {
        let data = try await ArtworkManager.shared.get(
            for: url,
            shouldCache: self is Album || self is Artist,
        )

        return PlatformImage(data: data)
    }
}

/// Represents an artist in the MPD database.
nonisolated struct Artist: Mediable, Searchable {
    nonisolated var id: String { name }

    let url: URL

    let name: String

    let added: Date?

    func getAlbums() async throws -> [Album] {
        try await ConnectionManager.command().getAlbums(by: self, from: .database)
    }
    
    func search(for field: SearchManager.SearchField) -> String? {
        switch field {
        case .artist:
            return name
        case .title, .album, .genre:
            return nil
        }
    }
}

/// Represents an album in the MPD database.
nonisolated struct Album: Mediable, Artworkable, Searchable {
    nonisolated var id: String { description }

    let url: URL

    let title: String
    let artist: Artist

    let date: String?
    let genre: String?

    let added: Date?

    nonisolated var description: String {
        "\(artist.name) - \(title)"
    }

    /// Fetches all songs in this album.
    ///
    /// - Returns: An array of Song objects belonging to this album.
    /// - Throws: An error if the command execution fails.
    func getSongs() async throws -> [Song] {
        try await ConnectionManager.command().getSongs(in: self, from: .database)
    }
    
    func search(for field: SearchManager.SearchField) -> String? {
        switch field {
        case .title:
            return title
        case .artist:
            return artist.name
        case .genre:
            return genre
        case .album:
            return nil
        }
    }
}

/// Represents a song in the MPD database.
///
/// Songs contain detailed metadata including title, artist, album, duration,
/// and more.
nonisolated struct Song: Mediable, Artworkable, Searchable {
    nonisolated var id: String { url.absoluteString }

    let url: URL

    let identifier: UInt32?
    let position: UInt32?

    let artist: String
    let title: String
    let duration: Double

    let disc: Int
    let track: Int

    let album: Album

    let date: String?
    let genre: String?

    let added: Date?

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
    
    func search(for field: SearchManager.SearchField) -> String? {
        switch field {
        case .title:
            return title
        case .artist:
            return artist
        case .album:
            return album.title
        case .genre:
            return genre
        }
    }
}

/// Represents a playlist in the MPD database.
///
/// Playlists are named collections of songs that can be saved and loaded.
nonisolated struct Playlist: Identifiable, Equatable, Hashable, Codable, Sendable {
    nonisolated var id: String { name }

    let name: String
}

/// Represents a complete sort descriptor combining option and direction.
nonisolated struct SortDescriptor: RawRepresentable, Equatable {
    let option: SortOption
    let direction: SortDirection

    init(option: SortOption, direction: SortDirection = .ascending) {
        self.option = option
        self.direction = direction
    }

    init?(rawValue: String) {
        let components = rawValue.split(separator: "_")
        guard let first = components.first,
              let option = SortOption(rawValue: String(first))
        else {
            return nil
        }

        self.option = option
        direction = components.count == 2 && components[1] == "descending" ? .descending : .ascending
    }

    var rawValue: String {
        "\(option.rawValue)_\(direction == .ascending ? "ascending" : "descending")"
    }
}
