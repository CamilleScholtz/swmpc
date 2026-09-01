//
//  TagType.swift
//  MPDKit
//
//  Created by Camille Scholtz on 01/09/2026.
//

/// A song tag type, spelled as the `tagtypes` command names it.
///
/// Only the tags MPDKit actually reads are listed. The set exists to tell a
/// server which tags to send back, so listing one nothing parses would just
/// pay for metadata on the wire that is then discarded.
///
/// Tags arrived in the protocol at different times — `Conductor` in 0.22,
/// `Ensemble` in 0.23, `Mood` and `TitleSort` in 0.24 — and a server rejects
/// a `tagtypes enable` naming one it does not know. Rather than track that
/// per tag, the wanted set is intersected with what the server reports, see
/// ``ConnectionManager/narrowing(_:to:available:)``.
public enum TagType: String, Sendable, Hashable, CaseIterable {
    case album = "Album"
    case albumArtist = "AlbumArtist"
    case albumArtistSort = "AlbumArtistSort"
    case albumSort = "AlbumSort"
    case artist = "Artist"
    case artistSort = "ArtistSort"
    case comment = "Comment"
    case composer = "Composer"
    case conductor = "Conductor"
    case disc = "Disc"
    case ensemble = "Ensemble"
    case genre = "Genre"
    case mood = "Mood"
    case name = "Name"
    case performer = "Performer"
    case title = "Title"
    case titleSort = "TitleSort"
    case track = "Track"

    /// The name as a server reports it from `tagtypes`, which compares
    /// case-insensitively.
    var identifier: String {
        rawValue.lowercased()
    }
}
