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
    public nonisolated var id: String {
        name
    }

    /// The name of the playlist.
    public let name: String

    /// The raw SF Symbol name representing this playlist in the UI. `nil`
    /// until one has been assigned.
    public var symbolName: String?

    /// Creates a new playlist with the given name.
    /// - Parameters:
    ///   - name: The name of the playlist.
    ///   - symbolName: The raw SF Symbol name representing the playlist.
    public init(name: String, symbolName: String? = nil) {
        self.name = name
        self.symbolName = symbolName
    }

    /// Playlist identity is the name alone; the symbol is derived metadata
    /// and must not affect equality, hashing, or navigation selection.
    public static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
