//
//  Playlist.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

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
