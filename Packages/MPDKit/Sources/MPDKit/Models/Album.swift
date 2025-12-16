//
//  Album.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

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
