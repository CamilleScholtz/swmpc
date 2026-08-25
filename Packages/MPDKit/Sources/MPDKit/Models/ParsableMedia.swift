//
//  ParsableMedia.swift
//  MPDKit
//
//  Created by Camille Scholtz on 22/04/2026.
//

/// A media type that can construct itself from an MPD response field map.
///
/// Conformers know how to read their own fields, which lets the connection
/// layer dispatch parsing through the type system rather than a generic
/// runtime cast.
public protocol ParsableMedia: Mediable {
    /// Builds an instance from a parsed key/value field map.
    ///
    /// - Parameters:
    ///   - fields: A lower-cased key map from the server response.
    ///   - index: Optional positional index used when the server omits the
    ///            song's `pos` field (e.g., when iterating over a playlist).
    /// - Throws: `ConnectionManagerError.malformedResponse` if a required
    ///           field is missing or invalid.
    static func parse(fields: [String: String], index: Int?) throws -> Self
}

extension Song: ParsableMedia {
    public static func parse(fields: [String: String], index: Int?) throws
        -> Song
    {
        guard let file = fields["file"] else {
            throw ConnectionManagerError.malformedResponse(
                "Missing or invalid file field",
            )
        }

        let albumArtistName = fields["albumartist"] ?? fields["artist"]
            ?? "Unknown Artist"

        let artist: String
        let title: String
        if let name = fields["name"], fields["artist"] == nil,
           fields["title"] == nil
        {
            if let separator = name.range(of: " - ") {
                artist = String(name[..<separator.lowerBound])
                title = String(name[separator.upperBound...])
            } else {
                artist = "Unknown Artist"
                title = name
            }
        } else {
            artist = fields["artist"] ?? "Unknown Artist"
            title = fields["title"] ?? "Unknown Title"
        }

        return Song(
            file: file,
            identifier: fields["id"].flatMap { UInt32($0) },
            position: fields["pos"].flatMap { UInt32($0) }
                ?? index.map { UInt32($0) },
            artist: artist,
            artistSort: fields["artistsort"],
            title: title,
            titleSort: fields["titlesort"],
            duration: fields["duration"].flatMap { Double($0) } ?? 0,
            disc: fields["disc"].flatMap { Int($0) } ?? 1,
            track: fields["track"].flatMap { Int($0) } ?? 1,
            genre: fields["genre"],
            composer: fields["composer"],
            performer: fields["performer"],
            conductor: fields["conductor"],
            ensemble: fields["ensemble"],
            mood: fields["mood"],
            comment: fields["comment"],
            album: Album(
                file: file,
                title: fields["album"] ?? "Unknown Album",
                titleSort: fields["albumsort"],
                artist: Artist(
                    file: file,
                    name: albumArtistName,
                    nameSort: fields["albumartistsort"],
                ),
            ),
        )
    }
}

extension Album: ParsableMedia {
    public static func parse(fields: [String: String], index _: Int?) throws
        -> Album
    {
        guard let file = fields["file"] else {
            throw ConnectionManagerError.malformedResponse(
                "Missing or invalid file field",
            )
        }

        let artistName = fields["albumartist"] ?? fields["artist"]
            ?? "Unknown Artist"

        return Album(
            file: file,
            title: fields["album"] ?? "Unknown Album",
            titleSort: fields["albumsort"],
            artist: Artist(
                file: file,
                name: artistName,
                nameSort: fields["albumartistsort"],
            ),
        )
    }
}

extension Artist: ParsableMedia {
    public static func parse(fields: [String: String], index _: Int?) throws
        -> Artist
    {
        guard let file = fields["file"] else {
            throw ConnectionManagerError.malformedResponse(
                "Missing or invalid file field",
            )
        }

        let name = fields["albumartist"] ?? fields["artist"] ?? "Unknown Artist"

        return Artist(
            file: file,
            name: name,
            nameSort: fields["albumartistsort"],
        )
    }
}
