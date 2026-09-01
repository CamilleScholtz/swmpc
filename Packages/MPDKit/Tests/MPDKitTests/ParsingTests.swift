//
//  ParsingTests.swift
//  MPDKit
//
//  Created by Camille Scholtz on 25/08/2026.
//

import Testing

@testable import MPDKit

@Suite("Song parsing")
struct SongParsingTests {
    @Test("Duration is read at full precision")
    func duration() throws {
        let song = try Song.parse(
            fields: ["file": "a.flac", "duration": "245.533"],
            index: nil,
        )

        #expect(song.duration == 245.533)
    }

    @Test("A song without a duration gets zero rather than failing")
    func missingDuration() throws {
        let song = try Song.parse(fields: ["file": "a.flac"], index: nil)

        #expect(song.duration == 0)
    }

    @Test("A duration that is not a number gets zero too")
    func unparsableDuration() throws {
        let song = try Song.parse(
            fields: ["file": "a.flac", "duration": "245,533"],
            index: nil,
        )

        #expect(song.duration == 0)
    }

    @Test("A response without a file is rejected")
    func missingFile() {
        #expect(throws: ConnectionManagerError.self) {
            try Song.parse(fields: ["title": "Orphan"], index: nil)
        }
    }

    @Test("The file is both the path and the identity")
    func fileIsIdentity() throws {
        let song = try Song.parse(fields: ["file": "a.flac"], index: nil)

        #expect(song.file == "a.flac")
        #expect(song.id == "a.flac")
    }

    @Test("Queue identity and position are read when the server sends them")
    func queueIdentity() throws {
        let song = try Song.parse(
            fields: ["file": "a.flac", "id": "42", "pos": "7"],
            index: 3,
        )

        #expect(song.identifier == 42)
        #expect(song.position == 7)
    }

    @Test("A song without a position falls back to its index in the response")
    func positionFallback() throws {
        let song = try Song.parse(fields: ["file": "a.flac"], index: 3)

        #expect(song.identifier == nil)
        #expect(song.position == 3)
    }

    @Test("A song outside any queue has neither identity nor position")
    func withoutQueuePlacement() throws {
        let song = try Song.parse(fields: ["file": "a.flac"], index: nil)

        #expect(song.identifier == nil)
        #expect(song.position == nil)
    }

    @Test("Tags that are absent become the unknown placeholders")
    func unknownPlaceholders() throws {
        let song = try Song.parse(fields: ["file": "a.flac"], index: nil)

        #expect(song.artist == "Unknown Artist")
        #expect(song.title == "Unknown Title")
        #expect(song.album.title == "Unknown Album")
        #expect(song.album.artist.name == "Unknown Artist")
        #expect(song.track == 1)
        #expect(song.disc == 1)
    }

    @Test("Tags nothing else covers are still carried through")
    func descriptiveTags() throws {
        let song = try Song.parse(
            fields: [
                "file": "a.flac", "genre": "Ambient", "composer": "Eno",
                "performer": "Fripp", "conductor": "Karajan",
                "ensemble": "Berliner", "mood": "Calm", "comment": "Ripped",
            ],
            index: nil,
        )

        #expect(song.genre == "Ambient")
        #expect(song.composer == "Eno")
        #expect(song.performer == "Fripp")
        #expect(song.conductor == "Karajan")
        #expect(song.ensemble == "Berliner")
        #expect(song.mood == "Calm")
        #expect(song.comment == "Ripped")
    }

    @Test("Sort tags are kept alongside the tags they sort")
    func sortTags() throws {
        let song = try Song.parse(
            fields: [
                "file": "a.flac", "artist": "The Beatles",
                "artistsort": "Beatles, The", "title": "Help!",
                "titlesort": "Help", "album": "Help!", "albumsort": "Help",
                "albumartist": "The Beatles",
                "albumartistsort": "Beatles, The",
            ],
            index: nil,
        )

        #expect(song.artistSort == "Beatles, The")
        #expect(song.titleSort == "Help")
        #expect(song.album.titleSort == "Help")
        #expect(song.album.artist.nameSort == "Beatles, The")
    }

    @Test("An album with no artist tag of its own borrows the song's")
    func albumArtistFallback() throws {
        let song = try Song.parse(
            fields: ["file": "a.flac", "artist": "Boards of Canada"],
            index: nil,
        )

        #expect(song.album.artist.name == "Boards of Canada")
    }

    @Test("An album artist tag wins over the song's artist")
    func albumArtistPreferred() throws {
        let song = try Song.parse(
            fields: [
                "file": "a.flac", "artist": "Kanye West",
                "albumartist": "Various Artists",
            ],
            index: nil,
        )

        #expect(song.artist == "Kanye West")
        #expect(song.album.artist.name == "Various Artists")
    }

    @Test("The album carries the song's own file, since MPD names no other")
    func albumFile() throws {
        let song = try Song.parse(
            fields: ["file": "music/a.flac", "album": "Kid A"],
            index: nil,
        )

        #expect(song.album.file == "music/a.flac")
        #expect(song.album.artist.file == "music/a.flac")
    }
}

@Suite("Stream naming")
struct StreamParsingTests {
    @Test("A stream's name is split on its first dash")
    func splitsName() throws {
        let song = try Song.parse(
            fields: ["file": "http://example.org/stream",
                     "name": "Boards of Canada - Roygbiv"],
            index: nil,
        )

        #expect(song.artist == "Boards of Canada")
        #expect(song.title == "Roygbiv")
    }

    @Test("Only the first dash separates, so titles may contain more")
    func splitsOnceOnly() throws {
        let song = try Song.parse(
            fields: ["file": "http://example.org/stream",
                     "name": "Radio - Now Playing - Roygbiv"],
            index: nil,
        )

        #expect(song.artist == "Radio")
        #expect(song.title == "Now Playing - Roygbiv")
    }

    @Test("A name with no separator is the whole title")
    func nameWithoutSeparator() throws {
        let song = try Song.parse(
            fields: ["file": "http://example.org/stream", "name": "NTS Radio"],
            index: nil,
        )

        #expect(song.artist == "Unknown Artist")
        #expect(song.title == "NTS Radio")
    }

    @Test("A hyphen without surrounding spaces does not separate")
    func requiresSpacedDash() throws {
        let song = try Song.parse(
            fields: ["file": "http://example.org/stream", "name": "Jay-Z"],
            index: nil,
        )

        #expect(song.artist == "Unknown Artist")
        #expect(song.title == "Jay-Z")
    }

    @Test("A real title tag keeps the name out of it")
    func titleTagWins() throws {
        let song = try Song.parse(
            fields: ["file": "http://example.org/stream",
                     "name": "Radio - Roygbiv", "title": "Roygbiv"],
            index: nil,
        )

        #expect(song.artist == "Unknown Artist")
        #expect(song.title == "Roygbiv")
    }

    @Test("A real artist tag keeps the name out of it too")
    func artistTagWins() throws {
        let song = try Song.parse(
            fields: ["file": "http://example.org/stream",
                     "name": "Radio - Roygbiv", "artist": "Boards of Canada"],
            index: nil,
        )

        #expect(song.artist == "Boards of Canada")
        #expect(song.title == "Unknown Title")
    }
}

@Suite("Album parsing")
struct AlbumParsingTests {
    @Test("An album is named by its album artist")
    func albumArtist() throws {
        let album = try Album.parse(
            fields: ["file": "a.flac", "album": "The Grey Album",
                     "artist": "Danger Mouse", "albumartist": "Various Artists"],
            index: nil,
        )

        #expect(album.title == "The Grey Album")
        #expect(album.artist.name == "Various Artists")
        #expect(album.id == "Various Artists - The Grey Album")
    }

    @Test("Without an album artist the artist names it")
    func artistFallback() throws {
        let album = try Album.parse(
            fields: ["file": "a.flac", "album": "Kid A", "artist": "Radiohead"],
            index: nil,
        )

        #expect(album.artist.name == "Radiohead")
    }

    @Test("An album with no tags at all is still an album")
    func placeholders() throws {
        let album = try Album.parse(fields: ["file": "a.flac"], index: nil)

        #expect(album.title == "Unknown Album")
        #expect(album.artist.name == "Unknown Artist")
    }

    @Test("Sort tags are carried")
    func sortTags() throws {
        let album = try Album.parse(
            fields: ["file": "a.flac", "album": "Help!", "albumsort": "Help",
                     "albumartist": "The Beatles",
                     "albumartistsort": "Beatles, The"],
            index: nil,
        )

        #expect(album.titleSort == "Help")
        #expect(album.artist.nameSort == "Beatles, The")
    }

    @Test("A response without a file is rejected")
    func missingFile() {
        #expect(throws: ConnectionManagerError.self) {
            try Album.parse(fields: ["album": "Orphan"], index: nil)
        }
    }

    @Test("The index is ignored, since only songs have positions")
    func ignoresIndex() throws {
        let album = try Album.parse(fields: ["file": "a.flac"], index: 4)

        #expect(album.file == "a.flac")
    }
}

@Suite("Artist parsing")
struct ArtistParsingTests {
    @Test("An artist is named by the album artist when there is one")
    func albumArtist() throws {
        let artist = try Artist.parse(
            fields: ["file": "a.flac", "artist": "Danger Mouse",
                     "albumartist": "Various Artists"],
            index: nil,
        )

        #expect(artist.name == "Various Artists")
        #expect(artist.id == "Various Artists")
    }

    @Test("Without an album artist the artist tag names it")
    func artistFallback() throws {
        let artist = try Artist.parse(
            fields: ["file": "a.flac", "artist": "Radiohead"],
            index: nil,
        )

        #expect(artist.name == "Radiohead")
    }

    @Test("An untagged file has an unknown artist")
    func placeholder() throws {
        let artist = try Artist.parse(fields: ["file": "a.flac"], index: nil)

        #expect(artist.name == "Unknown Artist")
        #expect(artist.nameSort == nil)
    }

    @Test("A response without a file is rejected")
    func missingFile() {
        #expect(throws: ConnectionManagerError.self) {
            try Artist.parse(fields: ["artist": "Orphan"], index: nil)
        }
    }
}

@Suite("Output parsing")
struct OutputParsingTests {
    @Test("An output reports its plugin when the server sends one")
    func withPlugin() throws {
        let output = try #require(Output([
            "outputid": "0", "outputname": "Stream", "plugin": "httpd",
            "outputenabled": "1",
        ]))

        #expect(output.plugin == "httpd")
        #expect(output.isHttpd)
        #expect(output.isEnabled)
    }

    @Test("An output missing any required field is not an output")
    func incomplete() {
        #expect(Output(["outputname": "Nameless", "plugin": "alsa"]) == nil)
        #expect(Output(["outputid": "0", "plugin": "alsa"]) == nil)
        #expect(Output(["outputid": "0", "outputname": "No plugin"]) == nil)
    }

    @Test("An output whose identifier is not a number is not an output")
    func unparsableIdentifier() {
        #expect(Output([
            "outputid": "first", "outputname": "Speakers", "plugin": "alsa",
        ]) == nil)
    }

    @Test("Only the exact enabled flag counts as enabled")
    func enabledFlag() throws {
        func output(_ enabled: String?) throws -> Output {
            var fields = ["outputid": "0", "outputname": "Speakers",
                          "plugin": "alsa"]
            fields["outputenabled"] = enabled

            return try #require(Output(fields))
        }

        #expect(try output("1").isEnabled)
        #expect(try output("0").isEnabled == false)
        #expect(try output(nil).isEnabled == false)
    }

    @Test("Anything but the httpd plugin streams nothing")
    func plugins() throws {
        let output = try #require(Output([
            "outputid": "1", "outputname": "Speakers", "plugin": "alsa",
        ]))

        #expect(!output.isHttpd)
    }

    @Test("Attributes are carried beside the fields, not among them")
    func attributes() throws {
        let output = try #require(Output(
            ["outputid": "0", "outputname": "Speakers", "plugin": "alsa"],
            attributes: ["dop": "0", "allowed_formats": ""],
        ))

        #expect(output.attributes == ["dop": "0", "allowed_formats": ""])
    }

    @Test("An output with no extra fields has no attributes")
    func withoutAttributes() throws {
        let output = try #require(Output([
            "outputid": "0", "outputname": "Speakers", "plugin": "alsa",
        ]))

        #expect(output.attributes.isEmpty)
    }
}

@Suite("Track and disc numbers")
struct OrdinalParsingTests {
    /// Parses a song carrying the given raw track and disc tags.
    private func song(track: String, disc: String) throws -> Song {
        try Song.parse(
            fields: ["file": "a.flac", "track": track, "disc": disc],
            index: nil,
        )
    }

    @Test("Plain numbers parse as themselves")
    func plain() throws {
        let parsed = try song(track: "3", disc: "2")

        #expect(parsed.track == 3)
        #expect(parsed.disc == 2)
    }

    @Test("Zero-padded numbers parse")
    func leadingZeroes() throws {
        #expect(try song(track: "007", disc: "01").track == 7)
        #expect(try song(track: "0010", disc: "01").track == 10)
    }

    @Test("Anything that is not a bare decimal falls back to the first")
    func fallback() throws {
        // Mopidy sends "3/12"; reported as mopidy/mopidy-mpd#83, not worked
        // around here.
        #expect(try song(track: "3/12", disc: "1/2").track == 1)
        #expect(try song(track: "A", disc: "").disc == 1)
    }

    @Test("A missing ordinal is the first, not the zeroth")
    func missing() throws {
        let parsed = try Song.parse(fields: ["file": "a.flac"], index: nil)

        #expect(parsed.track == 1)
        #expect(parsed.disc == 1)
    }
}

@Suite("Requested tags")
struct ParsableTagTests {
    @Test("A song reads every tag MPDKit knows about")
    func songReadsEverything() {
        #expect(Song.tags == Set(TagType.allCases))
    }

    @Test("Types that read less ask for less")
    func subsets() {
        #expect(Album.tags.isSubset(of: Song.tags))
        #expect(Artist.tags.isSubset(of: Album.tags))
        #expect(Album.tags != Song.tags)
        #expect(Artist.tags != Album.tags)
    }

    @Test("Every type reads the tags that name it")
    func namingTags() {
        #expect(Album.tags.contains(.album))
        #expect(Album.tags.contains(.albumArtist))
        #expect(Artist.tags.contains(.artist))
        #expect(Artist.tags.contains(.albumArtist))
        #expect(Song.tags.contains(.title))
    }
}

@Suite("Response lines")
struct ResponseLineTests {
    /// A manager with no connection behind it, since turning response lines
    /// into media is pure parsing.
    private let connection = ConnectionManager<CommandMode>(version: "0.24")

    @Test("A line is split into a lower-cased key and a trimmed value")
    func keyValue() async throws {
        let (key, value) = try await connection
            .parseLine("Artist:  Boards of Canada ")

        #expect(key == "artist")
        #expect(value == "Boards of Canada")
    }

    @Test("Only the first colon separates, so paths survive intact")
    func colonInValue() async throws {
        let (key, value) = try await connection
            .parseLine("file: music/Zappa: Live/a.flac")

        #expect(key == "file")
        #expect(value == "music/Zappa: Live/a.flac")
    }

    @Test("A line without a colon is malformed")
    func withoutColon() async {
        await #expect(throws: ConnectionManagerError.self) {
            try await connection.parseLine("OK")
        }

        await #expect(throws: ConnectionManagerError.self) {
            try await connection.parseLine("")
        }
    }

    @Test("Lines are grouped from each prefix to the next")
    func chunking() {
        #expect(connection.chunkLines(
            ["file: a.flac", "Title: A", "file: b.flac", "Title: B", "OK"],
            startingWith: "file",
        ) == [["file: a.flac", "Title: A"],
              ["file: b.flac", "Title: B", "OK"]])
    }

    @Test("Anything before the first prefix belongs to no chunk")
    func chunkingPreamble() {
        #expect(connection.chunkLines(
            ["changed: player", "file: a.flac"],
            startingWith: "file",
        ) == [["file: a.flac"]])
    }

    @Test("Nothing to chunk yields nothing")
    func chunkingEmpty() {
        #expect(connection.chunkLines([], startingWith: "file").isEmpty)
        #expect(connection.chunkLines(["OK"], startingWith: "file").isEmpty)
    }

    @Test("A single response is parsed into one media item")
    func parseOne() async throws {
        let song = try await connection.parse(
            ["file: a.flac", "Artist: Radiohead", "Title: Idioteque", "OK"],
            as: Song.self,
        )

        #expect(song.artist == "Radiohead")
        #expect(song.title == "Idioteque")
    }

    @Test("A malformed line fails the whole response")
    func parseMalformed() async {
        await #expect(throws: ConnectionManagerError.self) {
            try await connection.parse(["file: a.flac", "Artist"],
                                       as: Song.self)
        }
    }

    @Test("A response is split into one item per file")
    func parseMany() async throws {
        let songs = try await connection.parseArray(
            ["file: a.flac", "Title: A", "file: b.flac", "Title: B", "OK"],
            as: Song.self,
        )

        #expect(songs.count == 2)
        #expect(songs.map(\.title) == ["A", "B"])
        #expect(songs.allSatisfy { $0.position == nil })
    }

    @Test("Indexed parsing numbers songs the server did not place")
    func parseManyIndexed() async throws {
        let songs = try await connection.parseArray(
            ["file: a.flac", "file: b.flac", "file: c.flac", "OK"],
            as: Song.self,
            indexed: true,
        )

        #expect(songs.map(\.position) == [0, 1, 2])
    }

    @Test("A position the server did send wins over the index")
    func parseManyKeepsPosition() async throws {
        let songs = try await connection.parseArray(
            ["file: a.flac", "Pos: 9", "file: b.flac", "OK"],
            as: Song.self,
            indexed: true,
        )

        #expect(songs.map(\.position) == [9, 1])
    }

    @Test("An empty response parses into nothing")
    func parseNone() async throws {
        let songs = try await connection.parseArray(["OK"], as: Song.self)

        #expect(songs.isEmpty)
    }

    @Test("Albums come back deduplicated only by their identity, not here")
    func parseAlbums() async throws {
        let albums = try await connection.parseArray(
            ["file: a.flac", "Album: Kid A", "Artist: Radiohead",
             "file: b.flac", "Album: Kid A", "Artist: Radiohead", "OK"],
            as: Album.self,
        )

        #expect(albums.count == 2)
        #expect(albums[0] == albums[1])
    }
}
