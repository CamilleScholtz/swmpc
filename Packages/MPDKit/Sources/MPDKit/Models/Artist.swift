//
//  Artist.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

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
