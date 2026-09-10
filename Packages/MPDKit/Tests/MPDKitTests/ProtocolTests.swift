//
//  ProtocolTests.swift
//  MPDKit
//
//  Created by Camille Scholtz on 25/08/2026.
//

@testable import MPDKit
import Testing

@Suite("Protocol version comparison")
struct ProtocolVersionTests {
    @Test
    func `An unknown version supports nothing`() {
        #expect(!ProtocolVersion.isAtLeast("0.21", in: nil))
    }

    @Test
    func `A version is at least itself, however it is spelled`() {
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.21"))
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.21.0"))
    }

    @Test
    func `Components compare numerically, not lexically`() {
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.23"))
        #expect(!ProtocolVersion.isAtLeast("0.21", in: "0.9"))
        #expect(ProtocolVersion.isAtLeast("0.22.4", in: "0.23"))
        #expect(!ProtocolVersion.isAtLeast("0.22.4", in: "0.22"))
        #expect(ProtocolVersion.isAtLeast("0.22.4", in: "0.22.4"))
    }

    @Test
    func `Servers announcing an older protocol fall below the floor`() {
        // Mopidy-MPD announces 0.19; OwnTone announces 0.23.
        #expect(!ProtocolVersion.isAtLeast("0.21", in: "0.19.0"))
        #expect(ProtocolVersion.isAtLeast("0.21", in: "0.23.0"))
    }

    @Test
    func `A double-digit patch level is not mistaken for a lower one`() {
        #expect(ProtocolVersion.isAtLeast("0.23.5", in: "0.23.15"))
        #expect(ProtocolVersion.isAtLeast("0.9", in: "0.10"))
    }

    @Test
    func `A manager gates on the version its greeting reported`() async {
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

    @Test
    func `An argument is wrapped in double quotes by default`() {
        #expect(connection.escape("Kid A") == "\"Kid A\"")
    }

    @Test
    func `Double quotes inside an argument are escaped`() {
        #expect(connection.escape("Say \"Hi\"") == "\"Say \\\"Hi\\\"\"")
    }

    @Test
    func `Backslashes are doubled before anything else is escaped`() {
        #expect(connection.escape("AC\\DC") == "\"AC\\\\DC\"")
    }

    @Test
    func `Newlines cannot be represented, so they become spaces`() {
        #expect(connection.escape("drop\nthese\r\nlines", quote: nil)
            == "drop these  lines")
    }

    @Test
    func `An unquoted argument is neither wrapped nor quote-escaped`() {
        #expect(connection.escape("Kid A", quote: nil) == "Kid A")
        #expect(connection.escape("Say \"Hi\"", quote: nil) == "Say \"Hi\"")
    }

    @Test
    func `Single-quoted arguments escape single quotes instead`() {
        #expect(connection.escape("it's", quote: "'") == "'it\\'s'")
        #expect(connection.escape("say \"hi\"", quote: "'")
            == "'say \"hi\"'")
    }

    @Test
    func `An empty argument is still a well-formed one`() {
        #expect(connection.escape("") == "\"\"")
    }
}

@Suite("Query building")
struct QueryBuildingTests {
    /// A manager pinned to a server version, with no connection behind it.
    private func manager(_ version: String) -> ConnectionManager<CommandMode> {
        ConnectionManager<CommandMode>(version: version)
    }

    @Test
    func `A filter clause is parenthesised, and quoted unless composed`() {
        let connection = manager("0.24")

        #expect(connection.filter(key: "album", value: "Kid A")
            == "\"(album == 'Kid A')\"")
        #expect(connection.filter(key: "album", value: "Kid A", quote: false)
            == "(album == 'Kid A')")
    }

    @Test
    func `Quotes in values are escaped`() {
        #expect(manager("0.24").filter(key: "album", value: "Rock 'n' Roll")
            == "\"(album == 'Rock \\\\'n\\\\' Roll')\"")
    }

    @Test
    func `Double quotes in values are escaped for the outer quoting`() {
        #expect(manager("0.24").filter(key: "album", value: "Say \"Hello\"")
            == "\"(album == 'Say \\\"Hello\\\"')\"")
    }

    @Test
    func `The comparator is the caller's to choose`() {
        #expect(manager("0.24").filter(key: "title", value: "",
                                       comparator: "!=")
                == "\"(title != '')\"")
        #expect(manager("0.24").filter(key: "artist", value: "Autechre",
                                       comparator: "contains")
                == "\"(artist contains 'Autechre')\"")
    }

    @Test
    func `Unquoted clauses compose into a single quoted expression`() {
        let connection = manager("0.24")
        let album = connection.filter(key: "album", value: "Kid A",
                                      quote: false)
        let artist = connection.filter(key: "albumartist", value: "Radiohead",
                                       quote: false)

        #expect("\"(\(album) AND \(artist))\""
            == "\"((album == 'Kid A') AND (albumartist == 'Radiohead'))\"")
    }

    @Test
    func `Sorts carry the tag, and a minus prefix when descending`() async {
        #expect(await manager("0.24").sortSuffix(SortDescriptor(option: .album))
            == " sort albumsort")
        #expect(await manager("0.24").sortSuffix(SortDescriptor(option: .album,
                                                                direction: .descending))
                == " sort -albumsort")
    }

    @Test
    func `Sorting by song title waits for the TitleSort tag in 0.24`() async {
        let descriptor = SortDescriptor(option: .song)

        #expect(await manager("0.24").sortSuffix(descriptor) == " sort titlesort")
        #expect(await manager("0.23").sortSuffix(descriptor) == "")
        #expect(await manager("0.23").sortSuffix(SortDescriptor(option: .artist))
            == " sort albumartistsort")
    }

    @Test
    func `A descending title sort is dropped whole on an older server`() async {
        let descriptor = SortDescriptor(option: .song, direction: .descending)

        #expect(await manager("0.24").sortSuffix(descriptor)
            == " sort -titlesort")
        #expect(await manager("0.23").sortSuffix(descriptor) == "")
    }

    @Test
    func `A server that has not greeted us yet sorts on nothing recent`() async {
        let connection = ConnectionManager<CommandMode>()

        #expect(await connection.sortSuffix(SortDescriptor(option: .song))
            == "")
        #expect(await connection.sortSuffix(SortDescriptor(option: .album))
            == " sort albumsort")
    }

    @Test
    func `The last modified sort uses the tag as the protocol spells it`() async {
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

    @Test
    func `The mask is set and restored around the command it narrows`() {
        #expect(connection.narrowing("find x", to: Album.tags, available: modern)
            == ["tagtypes clear",
                "tagtypes enable Album AlbumArtist AlbumArtistSort AlbumSort Artist",
                "find x",
                "tagtypes all"])
    }

    @Test
    func `Tags the server has not got yet are never asked for`() {
        #expect(connection.narrowing("find x", to: Song.tags, available: floor)
            == ["tagtypes clear",
                "tagtypes enable Album AlbumArtist AlbumArtistSort AlbumSort Artist ArtistSort Comment Composer Disc Genre Name Performer Title Track",
                "find x",
                "tagtypes all"])
    }

    @Test
    func `A current server is asked for every tag a song reads`() {
        #expect(connection.narrowing("find x", to: Song.tags, available: modern)
            == ["tagtypes clear",
                "tagtypes enable Album AlbumArtist AlbumArtistSort AlbumSort Artist ArtistSort Comment Composer Conductor Disc Ensemble Genre Mood Name Performer Title TitleSort Track",
                "find x",
                "tagtypes all"])
    }

    @Test
    func `An artist listing asks for the three tags that name one`() {
        #expect(connection.narrowing("find x", to: Artist.tags,
                                     available: modern)
                == ["tagtypes clear",
                    "tagtypes enable AlbumArtist AlbumArtistSort Artist",
                    "find x",
                    "tagtypes all"])
    }

    @Test
    func `A server that will not say what it supports is queried as before`() {
        #expect(connection.narrowing("find x", to: Song.tags, available: [])
            == ["find x"])
    }

    @Test
    func `A server sharing no tag with the query is queried as before`() {
        #expect(connection.narrowing("find x", to: Album.tags,
                                     available: ["date", "label"])
                == ["find x"])
    }

    @Test
    func `Asking for everything the server has is not worth a mask`() {
        let exact = Set(Album.tags.map(\.identifier))

        #expect(connection.narrowing("find x", to: Album.tags, available: exact)
            == ["find x"])
    }

    @Test
    func `A result type that reads no tags narrows to nothing`() {
        #expect(connection.narrowing("find x", to: [], available: modern)
            == ["find x"])
    }

    @Test
    func `The command is passed through untouched, whatever it is`() {
        let command = "playlistfind \"(album == 'Kid A')\" sort date"

        #expect(connection.narrowing(command, to: Album.tags,
                                     available: modern)[2] == command)
    }

    @Test
    func `The enabled tags are listed in a stable order`() {
        #expect(connection.narrowing("find x", to: Album.tags,
                                     available: modern)
                == connection.narrowing("find x", to: Album.tags,
                                        available: modern))
    }
}
