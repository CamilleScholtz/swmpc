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

    @Test("A double-digit patch level is not mistaken for a lower one")
    func doubleDigits() {
        #expect(ProtocolVersion.isAtLeast("0.23.5", in: "0.23.15"))
        #expect(ProtocolVersion.isAtLeast("0.9", in: "0.10"))
    }

    @Test("A manager gates on the version its greeting reported")
    func managerGating() async {
        let connection = ConnectionManager<CommandMode>(version: "0.23")

        #expect(await connection.isVersionAtLeast("0.22.4"))
        #expect(await connection.isVersionAtLeast("0.24") == false)
        #expect(await ConnectionManager<CommandMode>()
            .isVersionAtLeast("0.21") == false)
    }
}

@Suite("Command escaping")
struct EscapingTests {
    /// A manager with no connection behind it, since escaping an argument is
    /// pure string building.
    private let connection = ConnectionManager<CommandMode>(version: "0.24")

    @Test("An argument is wrapped in double quotes by default")
    func wraps() {
        #expect(connection.escape("Kid A") == "\"Kid A\"")
    }

    @Test("Double quotes inside an argument are escaped")
    func escapesQuotes() {
        #expect(connection.escape("Say \"Hi\"") == "\"Say \\\"Hi\\\"\"")
    }

    @Test("Backslashes are doubled before anything else is escaped")
    func escapesBackslashes() {
        #expect(connection.escape("AC\\DC") == "\"AC\\\\DC\"")
    }

    @Test("Newlines cannot be represented, so they become spaces")
    func flattensNewlines() {
        #expect(connection.escape("drop\nthese\r\nlines", quote: nil)
            == "drop these  lines")
    }

    @Test("An unquoted argument is neither wrapped nor quote-escaped")
    func unquoted() {
        #expect(connection.escape("Kid A", quote: nil) == "Kid A")
        #expect(connection.escape("Say \"Hi\"", quote: nil) == "Say \"Hi\"")
    }

    @Test("Single-quoted arguments escape single quotes instead")
    func singleQuoted() {
        #expect(connection.escape("it's", quote: "'") == "'it\\'s'")
        #expect(connection.escape("say \"hi\"", quote: "'")
            == "'say \"hi\"'")
    }

    @Test("An empty argument is still a well-formed one")
    func empty() {
        #expect(connection.escape("") == "\"\"")
    }
}

@Suite("Query building")
struct QueryBuildingTests {
    /// A manager pinned to a server version, with no connection behind it.
    private func manager(_ version: String) -> ConnectionManager<CommandMode> {
        ConnectionManager<CommandMode>(version: version)
    }

    @Test("A filter clause is parenthesised, and quoted unless composed")
    func filter() {
        let connection = manager("0.24")

        #expect(connection.filter(key: "album", value: "Kid A")
            == "\"(album == 'Kid A')\"")
        #expect(connection.filter(key: "album", value: "Kid A", quote: false)
            == "(album == 'Kid A')")
    }

    @Test("Quotes in values are escaped")
    func filterEscaping() {
        #expect(manager("0.24").filter(key: "album", value: "Rock 'n' Roll")
            == "\"(album == 'Rock \\\\'n\\\\' Roll')\"")
    }

    @Test("Double quotes in values are escaped for the outer quoting")
    func filterDoubleQuoteEscaping() {
        #expect(manager("0.24").filter(key: "album", value: "Say \"Hello\"")
            == "\"(album == 'Say \\\"Hello\\\"')\"")
    }

    @Test("The comparator is the caller's to choose")
    func filterComparator() {
        #expect(manager("0.24").filter(key: "title", value: "",
                                       comparator: "!=")
            == "\"(title != '')\"")
        #expect(manager("0.24").filter(key: "artist", value: "Autechre",
                                       comparator: "contains")
            == "\"(artist contains 'Autechre')\"")
    }

    @Test("Unquoted clauses compose into a single quoted expression")
    func filterComposition() {
        let connection = manager("0.24")
        let album = connection.filter(key: "album", value: "Kid A",
                                      quote: false)
        let artist = connection.filter(key: "albumartist", value: "Radiohead",
                                       quote: false)

        #expect("\"(\(album) AND \(artist))\""
            == "\"((album == 'Kid A') AND (albumartist == 'Radiohead'))\"")
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

    @Test("A descending title sort is dropped whole on an older server")
    func titleSortTagDescending() async {
        let descriptor = SortDescriptor(option: .song, direction: .descending)

        #expect(await manager("0.24").sortSuffix(descriptor)
            == " sort -titlesort")
        #expect(await manager("0.23").sortSuffix(descriptor) == "")
    }

    @Test("A server that has not greeted us yet sorts on nothing recent")
    func sortWithoutVersion() async {
        let connection = ConnectionManager<CommandMode>()

        #expect(await connection.sortSuffix(SortDescriptor(option: .song))
            == "")
        #expect(await connection.sortSuffix(SortDescriptor(option: .album))
            == " sort albumsort")
    }

    @Test("The last modified sort uses the tag as the protocol spells it")
    func modifiedSort() async {
        #expect(await manager("0.24")
            .sortSuffix(SortDescriptor(option: .modified))
            == " sort Last-Modified")
        #expect(await manager("0.21")
            .sortSuffix(SortDescriptor(option: .modified,
                                       direction: .descending))
            == " sort -Last-Modified")
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

    @Test("An artist listing asks for the three tags that name one")
    func narrowsArtists() {
        #expect(connection.narrowing("find x", to: Artist.tags,
                                     available: modern)
            == ["tagtypes clear",
                "tagtypes enable AlbumArtist AlbumArtistSort Artist",
                "find x",
                "tagtypes all"])
    }

    @Test("A server that will not say what it supports is queried as before")
    func skipsWhenUnknown() {
        #expect(connection.narrowing("find x", to: Song.tags, available: [])
            == ["find x"])
    }

    @Test("A server sharing no tag with the query is queried as before")
    func skipsWhenDisjoint() {
        #expect(connection.narrowing("find x", to: Album.tags,
                                     available: ["date", "label"])
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

    @Test("The command is passed through untouched, whatever it is")
    func keepsCommand() {
        let command = "playlistfind \"(album == 'Kid A')\" sort date"

        #expect(connection.narrowing(command, to: Album.tags,
                                     available: modern)[2] == command)
    }

    @Test("The enabled tags are listed in a stable order")
    func stableOrder() {
        #expect(connection.narrowing("find x", to: Album.tags,
                                     available: modern)
            == connection.narrowing("find x", to: Album.tags,
                                    available: modern))
    }
}
