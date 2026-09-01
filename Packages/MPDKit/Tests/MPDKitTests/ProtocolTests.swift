//
//  ProtocolDialectTests.swift
//  MPDKit
//
//  Created by Camille Scholtz on 25/08/2026.
//

import Testing

@testable import MPDKit

@Suite("Protocol version comparison")
struct ProtocolVersionTests {
    @Test("An unknown version supports nothing")
    func unknownVersion() {
        #expect(!ProtocolVersion.isAtLeast("0.21", in: nil))
    }

    @Test("A version is at least itself, however it is spelled")
    func equalVersions() {
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.21"))
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.21.0"))
    }

    @Test("Components compare numerically, not lexically")
    func numericComparison() {
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.23"))
        #expect(!ProtocolVersion.isAtLeast("0.21", in: "0.9"))
        #expect(ProtocolVersion.isAtLeast("0.22.4", in: "0.23"))
        #expect(!ProtocolVersion.isAtLeast("0.22.4", in: "0.22"))
        #expect(ProtocolVersion.isAtLeast("0.22.4", in: "0.22.4"))
    }

    @Test("Servers announcing an older protocol fall below the floor")
    func belowFloor() {
        // Mopidy-MPD announces 0.19; OwnTone announces 0.23.
        #expect(!ProtocolVersion.isAtLeast("0.21", in: "0.19.0"))
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.23.0"))
    }
}

@Suite("Query building")
struct QueryBuildingTests {
    /// A manager pinned to a server version, with no connection behind it.
    private func manager(_ version: String) -> ConnectionManager<CommandMode> {
        ConnectionManager<CommandMode>(version: version)
    }

    @Test("A filter clause is parenthesised, and quoted unless composed")
    func filter() async {
        let connection = manager("0.24")

        #expect(await connection.filter(key: "album", value: "Kid A")
            == "\"(album == 'Kid A')\"")
        #expect(await connection.filter(key: "album", value: "Kid A", quote: false)
            == "(album == 'Kid A')")
    }

    @Test("Quotes in values are escaped")
    func filterEscaping() async {
        #expect(await manager("0.24").filter(key: "album", value: "Rock 'n' Roll")
            == "\"(album == 'Rock \\\\'n\\\\' Roll')\"")
    }

    @Test("Sorts carry the tag, and a minus prefix when descending")
    func sortDirection() async {
        #expect(await manager("0.24").sortSuffix(SortDescriptor(option: .album))
            == " sort albumsort")
        #expect(await manager("0.24").sortSuffix(SortDescriptor(option: .album,
                                                                direction: .descending))
            == " sort -albumsort")
    }

    @Test("Sorting by song title waits for the TitleSort tag in 0.24")
    func titleSortTag() async {
        let descriptor = SortDescriptor(option: .song)

        #expect(await manager("0.24").sortSuffix(descriptor) == " sort titlesort")
        #expect(await manager("0.23").sortSuffix(descriptor) == "")
        #expect(await manager("0.23").sortSuffix(SortDescriptor(option: .artist))
            == " sort albumartistsort")
    }
}

@Suite("Tag narrowing")
struct TagNarrowingTests {
    /// A manager with no connection behind it, since narrowing a command is
    /// pure string building once the server's tag list is known.
    private let connection = ConnectionManager<CommandMode>(version: "0.24")

    /// What a current server reports from `tagtypes`.
    private let modern: Set<String> = Set(TagType.allCases.map(\.identifier))
        .union(["date", "originaldate", "label", "work", "grouping",
                "composersort", "movement", "movementnumber", "showmovement",
                "location", "musicbrainz_artistid", "musicbrainz_albumid",
                "musicbrainz_albumartistid", "musicbrainz_trackid",
                "musicbrainz_releasetrackid", "musicbrainz_workid"])

    /// What a server at the supported floor reports: no Conductor (0.22),
    /// Ensemble (0.23), Mood or TitleSort (0.24).
    private let floor: Set<String> = [
        "artist", "artistsort", "album", "albumsort", "albumartist",
        "albumartistsort", "title", "track", "name", "genre", "date",
        "originaldate", "composer", "performer", "comment", "disc", "label",
        "musicbrainz_artistid", "musicbrainz_albumid",
        "musicbrainz_albumartistid", "musicbrainz_trackid",
        "musicbrainz_releasetrackid", "musicbrainz_workid",
    ]

    @Test("The mask is set and restored around the command it narrows")
    func narrowsAlbums() {
        #expect(connection.narrowing("find x", to: Album.tags, available: modern)
            == ["tagtypes clear",
                "tagtypes enable Album AlbumArtist AlbumArtistSort AlbumSort Artist",
                "find x",
                "tagtypes all"])
    }

    @Test("Tags the server has not got yet are never asked for")
    func skipsUnknownTags() {
        #expect(connection.narrowing("find x", to: Song.tags, available: floor)
            == ["tagtypes clear",
                "tagtypes enable Album AlbumArtist AlbumArtistSort AlbumSort Artist ArtistSort Comment Composer Disc Genre Name Performer Title Track",
                "find x",
                "tagtypes all"])
    }

    @Test("A current server is asked for every tag a song reads")
    func narrowsSongs() {
        #expect(connection.narrowing("find x", to: Song.tags, available: modern)
            == ["tagtypes clear",
                "tagtypes enable Album AlbumArtist AlbumArtistSort AlbumSort Artist ArtistSort Comment Composer Conductor Disc Ensemble Genre Mood Name Performer Title TitleSort Track",
                "find x",
                "tagtypes all"])
    }

    @Test("A server that will not say what it supports is queried as before")
    func skipsWhenUnknown() {
        #expect(connection.narrowing("find x", to: Song.tags, available: [])
            == ["find x"])
    }

    @Test("Asking for everything the server has is not worth a mask")
    func skipsWhenNothingToSave() {
        let exact = Set(Album.tags.map(\.identifier))

        #expect(connection.narrowing("find x", to: Album.tags, available: exact)
            == ["find x"])
    }

    @Test("A result type that reads no tags narrows to nothing")
    func skipsWithoutTags() {
        #expect(connection.narrowing("find x", to: [], available: modern)
            == ["find x"])
    }
}
