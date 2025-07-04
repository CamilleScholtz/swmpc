//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

/// A protocol that defines the requirements for media objects in the MPD
/// client.
///
/// Types conforming to this protocol represent media items that can be
/// managed by MPD.
protocol Mediable: Identifiable, Equatable, Hashable, Codable, Sendable {
    /// A unique identifier for the media item. This derived from MPD song
    /// metadata (`id`).
    /// - Note: This is `nil` for items not in the queue. It is NOT the stable
    ///         `Identifiable.id`.
    var identifier: UInt32? { get }

    /// The position of the item in a queue or playlist.
    /// - Note: This is `nil` for items not in a queue or playlist.
    var position: UInt32? { get }

    /// The URL or file path of the media item.
    /// - Note: This is relative to the MPD music directory. For albums and
    ///         artists, this should be the URL of a representative song (e.g.,
    ///         the first track) and is used primarily for fetching artwork. It
    ///         is NOT used for identity.
    var url: URL { get }
}

extension Mediable {
    /// The unique identifier used by SwiftUI's `Identifiable` protocol. Uses
    /// the URL as the unique identifier for media items.
    var id: URL { url }

    /// Compares two media items for equality based on their URLs.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side value to compare.
    ///   - rhs: The right-hand side value to compare.
    /// - Returns: `true` if the URLs are equal; otherwise, `false`.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url
    }

    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// - Parameter hasher: The hasher to use when combining the components of this instance.
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

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
        let data = try await ArtworkManager.shared.get(for: self, shouldCache: !(self is Song))
        return PlatformImage(data: data)
    }
}

/// Represents an artist in the MPD database.
///
/// Artists are identified by their name and can have associated albums.
struct Artist: Mediable {
    let identifier: UInt32?
    let position: UInt32?
    let url: URL

    let name: String

    // TODO: I don't really like this as it is not consisten with the other
    // structs, `Album` doesn't have [`Song`] for example. I haven't found
    // a more efficient way of doing this though.
    var albums: [Album]?
}

/// Represents an album in the MPD database.
///
/// Albums are identified by a combination of their title and artist.
struct Album: Mediable {
    let identifier: UInt32?
    let position: UInt32?
    let url: URL

    let artist: String
    let title: String
    let date: String

    var description: String {
        "\(artist) - \(title)"
    }
}

/// Represents a song in the MPD database.
///
/// Songs contain detailed metadata including title, artist, album, duration,
/// and more.
struct Song: Mediable {
    let identifier: UInt32?
    let position: UInt32?
    let url: URL

    let artist: String
    let title: String
    let duration: Double

    let albumArtist: String
    let albumTitle: String

    let disc: Int
    let track: Int

    var description: String {
        "\(artist) - \(title)"
    }

    /// Checks if the song is part of a specific album.
    ///
    /// - Parameter album: The album to check against.
    /// - Returns: `true` if the song belongs to the specified album, `false`
    ///            otherwise.
    func isIn(_ album: Album) -> Bool {
        albumTitle == album.title && albumArtist == album.artist
    }

    /// Checks if the song is by a specific artist.
    ///
    /// - Parameter artist: The artist to check against.
    /// - Returns: `true` if the song is by the specified artist, `false`
    ///            otherwise.
    func isBy(_ artist: Artist) -> Bool {
        albumArtist == artist.name
    }
}

/// Represents a playlist in the MPD database.
///
/// Playlists are named collections of songs that can be saved and loaded.
struct Playlist: Identifiable, Equatable, Hashable, Codable, Sendable {
    var id: String { name }

    let name: String
}
