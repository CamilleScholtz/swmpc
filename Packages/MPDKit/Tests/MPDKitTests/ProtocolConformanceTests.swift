//
//  ProtocolConformanceTests.swift
//  MPDKit
//
//  Created by Camille Scholtz on 01/09/2026.
//

import Foundation
@testable import MPDKit
import Testing

/// What MPDKit puts on the wire, and what it makes of what comes back,
/// checked against the MPD protocol documentation by driving a real
/// `ConnectionManager` against a stub server, see ``MPDStub``.
///
/// Every test here points the process-wide connection configuration at its
/// own stub, so the whole suite runs serially.
@Suite("MPD protocol", .serialized, .timeLimit(.minutes(1)))
struct MPDProtocolTests {
    @Suite("Handshake")
    struct HandshakeTests {
        @Test
        func `The greeting names the protocol version commands are gated on`() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.24.0") { _ in
                let version = try await ConnectionManager<CommandMode>
                    .command { await $0.version }

                #expect(version == "0.24.0")
            }
        }

        @Test
        func `A server below the supported floor is turned away`() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.19.0") { _ in
                await #expect(throws: ConnectionManagerError
                    .unsupportedServerVersion)
                {
                    try await ConnectionManager<CommandMode>.command { _ in }
                }
            }
        }

        @Test
        func `A server at the floor is accepted`() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.21.0") { _ in
                let version = try await ConnectionManager<CommandMode>
                    .command { await $0.version }

                #expect(version == "0.21.0")
            }
        }

        @Test
        func `Anything but the documented greeting is refused`() async throws {
            try await MPDStub.withServer(greeting: "OK") { _ in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command { _ in }
                }
            }
        }

        @Test
        func `A configured password is sent, quoted, before anything else`() async throws {
            try await MPDStub.withServer(password: "hunter2") { stub in
                try await ConnectionManager<CommandMode>.command { _ in }

                #expect(stub.requests == [["password \"hunter2\""]])
            }
        }

        @Test
        func `A password with protocol punctuation in it is escaped`() async throws {
            try await MPDStub.withServer(password: "say \"hi\"\\") { stub in
                try await ConnectionManager<CommandMode>.command { _ in }

                #expect(stub.requests == [["password \"say \\\"hi\\\"\\\\\""]])
            }
        }

        @Test
        func `Without a password nothing is sent before the first command`() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command { _ in }

                #expect(stub.requests.isEmpty)
            }
        }

        @Test
        func `A manager serves one connection and will not open a second`() async throws {
            try await MPDStub.withServer { _ in
                let connection = ConnectionManager<CommandMode>()
                try await connection.connect()

                await #expect(throws: ConnectionManagerError.self) {
                    try await connection.connect()
                }

                await connection.disconnect()
            }
        }
    }

    @Suite("Requests")
    struct RequestTests {
        @Test
        func `A single command is sent on its own line`() async throws {
            try await MPDStub.withServer { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.run(["status"])
                }

                #expect(stub.requests == [["status"]])
            }
        }

        @Test
        func `Several commands are wrapped in a command list`() async throws {
            try await MPDStub.withServer { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.run(["clear", "add /", "play"])
                }

                #expect(stub.requests == [["command_list_begin", "clear",
                                           "add /", "play",
                                           "command_list_end"]])
            }
        }

        @Test
        func `A command list answers as one response, ending in a single OK`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["volume: 42", "state: play"]),
            ]) { _ in
                let lines = try await ConnectionManager<CommandMode>.command {
                    try await $0.run(["status", "currentsong"])
                }

                #expect(lines == ["volume: 42", "state: play", "OK"])
            }
        }

        @Test
        func `An ACK is a protocol violation carrying the server's words`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.failure(code: 50, command: "load",
                                message: "No such playlist"),
            ]) { _ in
                await #expect(throws: ConnectionManagerError.protocolViolation(
                    "ACK [50@0] {load} No such playlist",
                )) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.run(["load \"nope\""])
                    }
                }
            }
        }

        @Test
        func `A server that hangs up mid-command is reported, not awaited`() async throws {
            try await MPDStub.withServer(replies: [MPDStub.hangUp]) { _ in
                await #expect(throws: (any Error).self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.run(["status"])
                    }
                }
            }
        }
    }

    @Suite("Player status")
    struct StatusTests {
        /// A status response carrying everything MPDKit reads, followed by
        /// the current song, as `status` and `currentsong` answer together.
        private static let full = MPDStub.reply([
            "volume: 42", "repeat: 0", "random: 1", "single: 0",
            "consume: 1", "playlist: 7", "playlistlength: 3", "state: play",
            "song: 1", "songid: 9", "elapsed: 12.500", "bitrate: 1024",
            "audio: 44100:16:2",
        ] + MPDStub.song("a.flac", title: "Idioteque", artist: "Radiohead",
                         album: "Kid A", duration: 245.533, position: 1,
                         identifier: 9))

        @Test
        func `Status and the current song are asked for in one round trip`() async throws {
            try await MPDStub.withServer(replies: [Self.full]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getStatusData()
                }

                #expect(stub.lastCommands == ["status", "currentsong"])
            }
        }

        @Test
        func `Every status field MPDKit reads is read`() async throws {
            try await MPDStub.withServer(replies: [Self.full]) { _ in
                let status = try await ConnectionManager<CommandMode>
                    .command { try await $0.getStatusData() }

                #expect(status.state == .play)
                #expect(status.isConsume == true)
                #expect(status.isRandom == true)
                #expect(status.isRepeat == false)
                #expect(status.elapsed == 12.5)
                #expect(status.volume == 42)
                #expect(status.bitrate == 1024)
                #expect(status.audioFormat == AudioFormat("44100:16:2"))
                #expect(status.song?.title == "Idioteque")
                #expect(status.song?.identifier == 9)
                #expect(status.song?.position == 1)
            }
        }

        @Test
        func `Each documented player state is understood`() async throws {
            for (value, state) in [("play", PlayerState.play),
                                   ("pause", .pause), ("stop", .stop)]
            {
                try await MPDStub.withServer(replies: [
                    MPDStub.reply(["state: \(value)"]),
                ]) { _ in
                    let status = try await ConnectionManager<CommandMode>
                        .command { try await $0.getStatusData() }

                    #expect(status.state == state)
                }
            }
        }

        @Test
        func `A state the protocol does not define is malformed`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["state: playing"]),
            ]) { _ in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.getStatusData()
                    }
                }
            }
        }

        @Test
        func `A stopped player reports no current song`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["state: stop", "volume: 0"]),
            ]) { _ in
                let status = try await ConnectionManager<CommandMode>
                    .command { try await $0.getStatusData() }

                #expect(status.state == .stop)
                #expect(status.song == nil)
            }
        }

        @Test
        func `Fields the server left out are left unknown`() async throws {
            try await MPDStub.withServer(replies: [MPDStub.reply()]) { _ in
                let status = try await ConnectionManager<CommandMode>
                    .command { try await $0.getStatusData() }

                #expect(status.state == nil)
                #expect(status.isConsume == nil)
                #expect(status.isRandom == nil)
                #expect(status.isRepeat == nil)
                #expect(status.elapsed == nil)
                #expect(status.volume == nil)
                #expect(status.bitrate == nil)
                #expect(status.audioFormat == nil)
                #expect(status.song == nil)
            }
        }

        @Test
        func `A server with no mixer reports its volume as minus one`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["state: play", "volume: -1"]),
            ]) { _ in
                let status = try await ConnectionManager<CommandMode>
                    .command { try await $0.getStatusData() }

                #expect(status.volume == -1)
            }
        }

        @Test
        func `The one-shot modes MPD 0.24 added read as off, not on`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["state: play", "consume: oneshot",
                               "single: oneshot"]),
            ]) { _ in
                let status = try await ConnectionManager<CommandMode>
                    .command { try await $0.getStatusData() }

                #expect(status.isConsume == false)
            }
        }

        @Test
        func `A DSD stream reports a rate and channels but no bit depth`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["state: play", "audio: 2822400:dsd:2"]),
            ]) { _ in
                let status = try await ConnectionManager<CommandMode>
                    .command { try await $0.getStatusData() }

                #expect(status.audioFormat?.sampleRate == 2_822_400)
                #expect(status.audioFormat?.bits == nil)
                #expect(status.audioFormat?.channels == 2)
            }
        }
    }

    @Suite("Database statistics")
    struct StatsTests {
        @Test
        func `Statistics are asked for with one command`() async throws {
            try await MPDStub.withServer(replies: [MPDStub.reply()]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getStatsData()
                }

                #expect(stub.lastCommands == ["stats"])
            }
        }

        @Test
        func `Every documented statistic MPDKit reads is read`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["artists: 12", "albums: 34", "songs: 567",
                               "uptime: 890", "db_playtime: 12345",
                               "db_update: 1700000000", "playtime: 42"]),
            ]) { _ in
                let stats = try await ConnectionManager<CommandMode>
                    .command { try await $0.getStatsData() }

                #expect(stats.artists == 12)
                #expect(stats.albums == 34)
                #expect(stats.songs == 567)
                #expect(stats.uptime == 890)
                #expect(stats.playtime == 12345)
                #expect(stats.update == 1_700_000_000)
            }
        }
    }

    @Suite("Argument escaping")
    struct EscapingTests {
        @Test
        func `The protocol's own escaping example goes out as documented`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getSongs(by: Artist(file: "a.flac",
                                                     name: "foo'bar\"",
                                                     nameSort: nil))
                }

                #expect(stub.lastCommands
                    == ["find \"(artist == 'foo\\\\'bar\\\"')\" sort date"])
            }
        }

        @Test
        func `A backslash is doubled twice over, for value and for protocol`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getSongs(by: Artist(file: "a.flac",
                                                     name: "AC\\DC",
                                                     nameSort: nil))
                }

                #expect(stub.lastCommands
                    == ["find \"(artist == 'AC\\\\\\\\DC')\" sort date"])
            }
        }

        @Test
        func `A newline cannot ride along on a line-based protocol`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getSongs(from: .playlist(
                        Playlist(name: "Focus\nplay"),
                    ))
                }

                #expect(stub.lastCommands == ["listplaylistinfo \"Focus play\""])
            }
        }

        @Test
        func `Values outside ASCII survive both ways, as UTF-8`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("坂本龍一/async.flac", title: "音楽",
                                           artist: "坂本龍一",
                                           album: "async")),
            ]) { stub in
                let songs = try await ConnectionManager<CommandMode>.command {
                    try await $0.getSongs(by: Artist(file: "a.flac",
                                                     name: "坂本龍一",
                                                     nameSort: nil))
                }

                #expect(stub.lastCommands
                    == ["find \"(artist == '坂本龍一')\" sort date"])
                #expect(songs.first?.title == "音楽")
                #expect(songs.first?.file
                    == "坂本龍一/async.flac")
            }
        }

        @Test
        func `A response line that is not UTF-8 is malformed`() async throws {
            var reply = Data("file: ".utf8)
            reply.append(contentsOf: [0xFF, 0xFE, 0x0A])
            reply.append(Data("OK\n".utf8))

            try await MPDStub.withServer(replies: [reply]) { _ in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.run(["playlistinfo"])
                    }
                }
            }
        }

        @Test
        func `A quoted argument keeps its spaces in one argument`() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.renamePlaylist(Playlist(name: "Old name"),
                                                to: "New \"name\"")
                }

                #expect(stub.lastCommands
                    == ["rename \"Old name\" \"New \\\"name\\\"\""])
            }
        }
    }

    @Suite("Database queries")
    struct QueryTests {
        @Test
        func `Albums are found through the first track of each`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", album: "Kid A",
                                           albumArtist: "Radiohead")
                        + MPDStub.song("b.flac", album: "Amnesiac",
                                       albumArtist: "Radiohead")),
            ]) { stub in
                let albums = try await ConnectionManager<CommandMode>
                    .command { try await $0.getAlbums() }

                #expect(stub.lastCommands
                    == ["find \"(track == '1')\" sort albumartistsort"])
                #expect(albums.map(\.id) == ["Radiohead - Kid A",
                                             "Radiohead - Amnesiac"])
            }
        }

        @Test
        func `An album found twice is listed once`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", album: "Kid A",
                                           albumArtist: "Radiohead")
                        + MPDStub.song("b.flac", album: "Kid A",
                                       albumArtist: "Radiohead")),
            ]) { _ in
                let albums = try await ConnectionManager<CommandMode>
                    .command { try await $0.getAlbums() }

                #expect(albums.count == 1)
            }
        }

        @Test
        func `The sort argument carries the descriptor asked for`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getAlbums(sort: SortDescriptor(
                        option: .album, direction: .descending,
                    ))
                }

                #expect(stub.lastCommands
                    == ["find \"(track == '1')\" sort -albumsort"])
            }
        }

        @Test
        func `An artist's albums are found by album artist, in release order`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getAlbums(
                        by: Artist(file: "a.flac", name: "Radiohead",
                                   nameSort: nil),
                        from: .database,
                    )
                }

                #expect(stub.lastCommands
                    == ["find \"(albumartist == 'Radiohead')\" sort date"])
            }
        }

        @Test
        func `The queue is sorted only on a server whose playlistfind can`() async throws {
            let artist = Artist(file: "a.flac", name: "Radiohead",
                                nameSort: nil)

            try await MPDStub.withServer(greeting: "OK MPD 0.24.0", replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getAlbums(by: artist, from: .queue)
                }

                #expect(stub.lastCommands
                    == ["playlistfind \"(albumartist == 'Radiohead')\" sort date"])
            }

            try await MPDStub.withServer(greeting: "OK MPD 0.23.5", replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getAlbums(by: artist, from: .queue)
                }

                #expect(stub.lastCommands
                    == ["playlistfind \"(albumartist == 'Radiohead')\""])
            }
        }

        @Test
        func `Only the database and the queue can be asked for an artist`() async throws {
            try await MPDStub.withServer { _ in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.getAlbums(
                            by: Artist(file: "a.flac", name: "Radiohead",
                                       nameSort: nil),
                            from: .playlist(Playlist(name: "Focus")),
                        )
                    }
                }
            }
        }

        @Test
        func `Artists and their album counts come from the album listing`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", album: "Kid A",
                                           albumArtist: "Radiohead")
                        + MPDStub.song("b.flac", album: "Amnesiac",
                                       albumArtist: "Radiohead")
                        + MPDStub.song("c.flac", album: "Untrue",
                                       albumArtist: "Burial")),
            ]) { _ in
                let listing = try await ConnectionManager<CommandMode>
                    .command { try await $0.getArtistsWithAlbumCounts() }

                #expect(listing.artists.map(\.name) == ["Radiohead", "Burial"])
                #expect(listing.albumCounts == ["Radiohead": 2, "Burial": 1])
            }
        }

        @Test
        func `Each source is read with the command the protocol gives it`() async throws {
            let sources: [(Source, String)] = [
                (.database, "find \"(title != '')\" sort albumartistsort"),
                (.queue, "playlistinfo"),
                (.playlist(Playlist(name: "Focus")),
                 "listplaylistinfo \"Focus\""),
                (.favorites, "listplaylistinfo \"Favorites\""),
            ]

            for (source, command) in sources {
                try await MPDStub.withServer(replies: [
                    MPDStub.reply(), MPDStub.reply(),
                ]) { stub in
                    _ = try await ConnectionManager<CommandMode>.command {
                        try await $0.getSongs(from: source)
                    }

                    #expect(stub.lastCommands == [command])
                }
            }
        }

        @Test
        func `Songs from a list are numbered when the server gives no position`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac")
                    + MPDStub.song("b.flac") + MPDStub.song("c.flac")),
            ]) { _ in
                let songs = try await ConnectionManager<CommandMode>
                    .command { try await $0.getSongs(from: .queue) }

                #expect(songs.map(\.position) == [0, 1, 2])
            }
        }

        @Test
        func `A position the queue reported is kept as the queue's own`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 4,
                                           identifier: 9)
                        + MPDStub.song("b.flac", position: 5, identifier: 10)),
            ]) { _ in
                let songs = try await ConnectionManager<CommandMode>
                    .command { try await $0.getSongs(from: .queue) }

                #expect(songs.map(\.position) == [4, 5])
                #expect(songs.map(\.identifier) == [9, 10])
            }
        }

        @Test
        func `An album's songs are asked for with one conjoined filter`() async throws {
            let album = Album(file: "a.flac", title: "Kid A", titleSort: nil,
                              artist: Artist(file: "a.flac",
                                             name: "Radiohead",
                                             nameSort: nil))

            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getSongs(in: album, from: .database)
                }

                #expect(stub.lastCommands
                    == ["find \"((album == 'Kid A') AND (albumartist == 'Radiohead'))\""])
            }

            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getSongs(in: album, from: .queue)
                }

                #expect(stub.lastCommands
                    == ["playlistfind \"((album == 'Kid A') AND (albumartist == 'Radiohead'))\""])
            }
        }

        @Test
        func `An album's songs come back by disc and then by track`() async throws {
            let album = Album(file: "a.flac", title: "Kid A", titleSort: nil,
                              artist: Artist(file: "a.flac",
                                             name: "Radiohead",
                                             nameSort: nil))

            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("d2t1.flac", disc: 2, track: 1)
                    + MPDStub.song("d1t10.flac", disc: 1, track: 10)
                    + MPDStub.song("d1t2.flac", disc: 1, track: 2)),
            ]) { _ in
                let songs = try await ConnectionManager<CommandMode>.command {
                    try await $0.getSongs(in: album, from: .database)
                }

                #expect(songs.map(\.file)
                    == ["d1t2.flac", "d1t10.flac", "d2t1.flac"])
            }
        }

        @Test
        func `The queue keeps its own order, whatever the tags say`() async throws {
            let album = Album(file: "a.flac", title: "Kid A", titleSort: nil,
                              artist: Artist(file: "a.flac",
                                             name: "Radiohead",
                                             nameSort: nil))

            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("d2t1.flac", disc: 2, track: 1)
                    + MPDStub.song("d1t2.flac", disc: 1, track: 2)),
            ]) { _ in
                let songs = try await ConnectionManager<CommandMode>.command {
                    try await $0.getSongs(in: album, from: .queue)
                }

                #expect(songs.map(\.file) == ["d2t1.flac", "d1t2.flac"])
            }
        }

        @Test
        func `An artist's songs come back album by album, each in order`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("kid-a-2.flac", album: "Kid A",
                                           albumArtist: "Radiohead", track: 2)
                        + MPDStub.song("amnesiac-1.flac", album: "Amnesiac",
                                       albumArtist: "Radiohead", track: 1)
                        + MPDStub.song("kid-a-1.flac", album: "Kid A",
                                       albumArtist: "Radiohead", track: 1)),
            ]) { stub in
                let songs = try await ConnectionManager<CommandMode>.command {
                    try await $0.getSongs(by: Artist(file: "a.flac",
                                                     name: "Radiohead",
                                                     nameSort: nil))
                }

                #expect(stub.lastCommands
                    == ["find \"(artist == 'Radiohead')\" sort date"])
                #expect(songs.map(\.file) == ["kid-a-1.flac", "kid-a-2.flac",
                                              "amnesiac-1.flac"])
            }
        }

        @Test
        func `Playlists are listed by name, ignoring their timestamps`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["playlist: Focus",
                               "Last-Modified: 2026-08-01T12:00:00Z",
                               "playlist: Sleep",
                               "Last-Modified: 2026-08-02T12:00:00Z"]),
            ]) { stub in
                let playlists = try await ConnectionManager<CommandMode>
                    .command { try await $0.getPlaylists() }

                #expect(stub.lastCommands == ["listplaylists"])
                #expect(playlists.map(\.name) == ["Focus", "Sleep"])
            }
        }

        @Test
        func `Outputs are listed with the fields the protocol names`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["outputid: 0", "outputname: Speakers",
                               "plugin: alsa", "outputenabled: 1",
                               "attribute: dop=0",
                               "attribute: allowed_formats=",
                               "outputid: 1", "outputname: Stream",
                               "plugin: httpd", "outputenabled: 0"]),
            ]) { stub in
                let outputs = try await ConnectionManager<CommandMode>
                    .command { try await $0.getOutputs() }

                #expect(stub.lastCommands == ["outputs"])
                #expect(outputs.map(\.id) == [0, 1])
                #expect(outputs.map(\.name) == ["Speakers", "Stream"])
                #expect(outputs.map(\.isEnabled) == [true, false])
                #expect(outputs.last?.isHttpd == true)
                #expect(outputs.first?.attributes
                    == ["dop": "0", "allowed_formats": ""])
                #expect(outputs.last?.attributes.isEmpty == true)
            }
        }
    }

    @Suite("Tag narrowing")
    struct NarrowingTests {
        /// What a server answers `tagtypes` with: more than any one query
        /// reads, so narrowing is always worth it.
        private static let available = MPDStub.tagTypes([
            "Artist", "ArtistSort", "Album", "AlbumSort", "AlbumArtist",
            "AlbumArtistSort", "Title", "TitleSort", "Track", "Disc", "Name",
            "Genre", "Mood", "Comment", "Composer", "Performer", "Conductor",
            "Ensemble", "Date", "MUSICBRAINZ_ARTISTID",
        ])

        @Test
        func `The mask is set and put back inside the query's own list`() async throws {
            try await MPDStub.withServer(replies: [
                Self.available, MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getAlbums()
                }

                #expect(stub.requests.last == [
                    "command_list_begin",
                    "tagtypes clear",
                    "tagtypes enable Album AlbumArtist AlbumArtistSort AlbumSort Artist",
                    "find \"(track == '1')\" sort albumartistsort",
                    "tagtypes all",
                    "command_list_end",
                ])
            }
        }

        @Test
        func `The server is asked what it supports once, then remembered`() async throws {
            try await MPDStub.withServer(replies: [
                Self.available, MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    _ = try await $0.getAlbums()

                    return try await $0.getAlbums()
                }

                #expect(stub.commands.filter { $0 == ["tagtypes"] }.count == 1)
                #expect(stub.requests.count == 3)
            }
        }

        @Test
        func `A server that names no tags is queried without a mask`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getAlbums()
                }

                #expect(stub.requests
                    == [["tagtypes"],
                        ["find \"(track == '1')\" sort albumartistsort"]])
            }
        }

        @Test
        func `A server that names no tags is not asked a second time`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    _ = try await $0.getAlbums()

                    return try await $0.getAlbums()
                }

                let find = ["find \"(track == '1')\" sort albumartistsort"]

                #expect(stub.commands == [["tagtypes"], find, find])
            }
        }

        @Test
        func `A query that fails takes the mask off again`() async throws {
            try await MPDStub.withServer(replies: [
                Self.available,
                MPDStub.failure(code: 2, index: 2, command: "find",
                                message: "Unknown filter type"),
                MPDStub.reply(),
            ]) { stub in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.getAlbums()
                    }
                }

                #expect(stub.lastCommands == ["tagtypes all"])
            }
        }
    }

    @Suite("Queue editing")
    struct QueueTests {
        /// A song at a known place in the queue.
        private func song(_ file: String, position: UInt32? = nil,
                          identifier: UInt32? = nil) -> Song
        {
            Song(file: file, identifier: identifier, position: position,
                 artist: "Radiohead", artistSort: nil, title: file,
                 titleSort: nil, duration: 0, disc: 1, track: 1, genre: nil,
                 composer: nil, performer: nil, conductor: nil,
                 ensemble: nil, mood: nil, comment: nil,
                 album: Album(file: file, title: "Kid A", titleSort: nil,
                              artist: Artist(file: file, name: "Radiohead",
                                             nameSort: nil)))
        }

        @Test
        func `Only songs the queue has not got are added`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)),
                MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.add(songs: [song("a.flac"),
                                             song("b.flac")],
                                     to: .queue)
                }

                #expect(stub.lastCommands == ["add \"b.flac\""])
            }
        }

        @Test
        func `Adding nothing new sends nothing at all`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.add(songs: [song("a.flac")], to: .queue)
                }

                #expect(stub.commands.last != ["add \"a.flac\""])
                #expect(stub.requests.count == 2)
            }
        }

        @Test
        func `A playlist is added to by name, song by song`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.add(songs: [song("a.flac"),
                                             song("b.flac")],
                                     to: .playlist(Playlist(name: "Focus")))
                }

                #expect(stub.lastCommands == ["playlistadd \"Focus\" \"a.flac\"",
                                              "playlistadd \"Focus\" \"b.flac\""])
            }
        }

        @Test
        func `The database cannot be added to, and is not read to find out`() async throws {
            try await MPDStub.withServer { stub in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.add(songs: [self.song("a.flac")],
                                         to: .database)
                    }
                }

                #expect(stub.requests.isEmpty)
            }
        }

        @Test
        func `The database cannot be removed from either`() async throws {
            try await MPDStub.withServer { stub in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.remove(songs: [self.song("a.flac")],
                                            from: .database)
                    }
                }

                #expect(stub.requests.isEmpty)
            }
        }

        @Test
        func `A run of queue positions is deleted as one half-open range`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)
                    + MPDStub.song("b.flac", position: 1)
                    + MPDStub.song("c.flac", position: 2)
                    + MPDStub.song("d.flac", position: 3)
                    + MPDStub.song("e.flac", position: 4)),
                MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.remove(songs: [song("b.flac"),
                                                song("c.flac"),
                                                song("d.flac")],
                                        from: .queue)
                }

                #expect(stub.lastCommands == ["delete 1:4"])
            }
        }

        @Test
        func `A single position is deleted by position alone`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)
                    + MPDStub.song("b.flac", position: 1)),
                MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.remove(songs: [song("b.flac")],
                                        from: .queue)
                }

                #expect(stub.lastCommands == ["delete 1"])
            }
        }

        @Test
        func `Scattered positions are deleted from the back forwards`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)
                    + MPDStub.song("b.flac", position: 1)
                    + MPDStub.song("c.flac", position: 2)
                    + MPDStub.song("d.flac", position: 3)
                    + MPDStub.song("e.flac", position: 4)),
                MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.remove(songs: [song("e.flac"),
                                                song("c.flac")],
                                        from: .queue)
                }

                #expect(stub.lastCommands == ["delete 4", "delete 2"])
            }
        }

        @Test
        func `A playlist is deleted from one position at a time, descending`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)
                    + MPDStub.song("b.flac", position: 1)
                    + MPDStub.song("c.flac", position: 2)),
                MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.remove(songs: [song("b.flac"),
                                                song("c.flac")],
                                        from: .playlist(
                                            Playlist(name: "Focus"),
                                        ))
                }

                #expect(stub.lastCommands == ["playlistdelete \"Focus\" 2",
                                              "playlistdelete \"Focus\" 1"])
            }
        }

        @Test
        func `Removing songs the source has not got sends nothing`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.remove(songs: [song("z.flac")],
                                        from: .queue)
                }

                #expect(stub.requests.count == 2)
            }
        }

        @Test
        func `A move names where the song is now and where it should go`() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.move(song("a.flac", position: 3),
                                      to: 1, in: .queue)
                    try await $0.move(song("a.flac", position: 3),
                                      to: 1,
                                      in: .playlist(Playlist(name: "Focus")))
                }

                #expect(stub.commands.flatMap(\.self)
                    == ["move 3 1", "playlistmove \"Focus\" 3 1"])
            }
        }

        @Test
        func `A song that is nowhere cannot be moved`() async throws {
            try await MPDStub.withServer { _ in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.move(self.song("a.flac"), to: 1,
                                          in: .queue)
                    }
                }
            }
        }

        @Test
        func `A queued song is played by the identity the queue gave it`() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.play(song("a.flac", position: 0,
                                           identifier: 9))
                }

                #expect(stub.lastCommands == ["playid 9"])
            }
        }

        @Test
        func `An album is queued with addid, then played by the id given back`() async throws {
            let album = Album(file: "a.flac", title: "Kid A", titleSort: nil,
                              artist: Artist(file: "a.flac",
                                             name: "Radiohead",
                                             nameSort: nil))

            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", track: 1)
                    + MPDStub.song("b.flac", track: 2)),
                MPDStub.reply(),
                MPDStub.reply(["Id: 7", "Id: 8"]),
                MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.play(album)
                }

                #expect(stub.commands == [
                    ["tagtypes"],
                    ["find \"((album == 'Kid A') AND (albumartist == 'Radiohead'))\""],
                    ["playlistinfo"],
                    ["addid \"a.flac\"", "addid \"b.flac\""],
                    ["playid 7"],
                ])
            }
        }

        @Test
        func `An album already in the queue is played where it stands`() async throws {
            let album = Album(file: "a.flac", title: "Kid A", titleSort: nil,
                              artist: Artist(file: "a.flac",
                                             name: "Radiohead",
                                             nameSort: nil))

            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", track: 1)),
                MPDStub.reply(MPDStub.song("a.flac", position: 3,
                                           identifier: 11)),
                MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.play(album)
                }

                #expect(stub.lastCommands == ["playid 11"])
            }
        }

        @Test
        func `An album with no songs behind it cannot be played`() async throws {
            let album = Album(file: "a.flac", title: "Kid A", titleSort: nil,
                              artist: Artist(file: "a.flac",
                                             name: "Radiohead",
                                             nameSort: nil))

            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(),
            ]) { _ in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.play(album)
                    }
                }
            }
        }
    }

    @Suite("Stored playlists")
    struct PlaylistTests {
        @Test
        func `Loading a playlist replaces the queue and starts it`() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.loadPlaylist(Playlist(name: "Focus"))
                }

                #expect(stub.lastCommands
                    == ["clear", "load \"Focus\"", "play"])
            }
        }

        @Test
        func `Loading everything adds the whole music directory`() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.loadPlaylist()
                }

                #expect(stub.lastCommands == ["clear", "add /", "play"])
            }
        }

        @Test
        func `A new playlist is saved and then emptied`() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.createPlaylist(named: "Focus")
                }

                #expect(stub.commands == [["save \"Focus\""],
                                          ["playlistclear \"Focus\""]])
            }
        }

        @Test
        func `A playlist that cannot be emptied is taken away again`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.failure(code: 5, command: "playlistclear",
                                message: "unknown command"),
                MPDStub.reply(),
            ]) { stub in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.createPlaylist(named: "Focus")
                    }
                }

                #expect(stub.commands == [["save \"Focus\""],
                                          ["playlistclear \"Focus\""],
                                          ["rm \"Focus\""]])
            }
        }

        @Test
        func `Renaming and removing name the playlist as the protocol does`() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.renamePlaylist(Playlist(name: "Focus"),
                                                to: "Deep focus")
                    try await $0.removePlaylist(Playlist(name: "Sleep"))
                }

                #expect(stub.commands.flatMap(\.self)
                    == ["rename \"Focus\" \"Deep focus\"", "rm \"Sleep\""])
            }
        }
    }

    @Suite("Playback and options")
    struct PlaybackTests {
        @Test
        func `Every command is spelled the way the protocol spells it`() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command { connection in
                    try await connection.pause(true)
                    try await connection.pause(false)
                    try await connection.previous()
                    try await connection.next()
                    try await connection.stop()
                    try await connection.consume(true)
                    try await connection.random(false)
                    try await connection.repeat(true)
                    try await connection.seek(12.5)
                    try await connection.setVolume(80)
                    try await connection.clearQueue()
                    try await connection.toggleOutput(
                        Output(id: 3, name: "Speakers", plugin: "alsa",
                               isEnabled: true),
                    )
                }

                #expect(stub.commands.flatMap(\.self) == [
                    "pause 1", "pause 0", "previous", "next", "stop",
                    "consume 1", "random 0", "repeat 1", "seekcur 12.5",
                    "setvol 80", "clear", "toggleoutput 3",
                ])
            }
        }

        @Test
        func `A database update rescans only when forced to`() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.update()
                    try await $0.update(force: true)
                }

                #expect(stub.commands.flatMap(\.self) == ["update", "rescan"])
            }
        }
    }

    @Suite("Idle")
    struct IdleTests {
        /// Connects an idle-mode manager, runs `body`, and hangs up.
        private func idling<T: Sendable>(
            _ body: (ConnectionManager<IdleMode>) async throws -> T,
        ) async throws -> T {
            let connection = ConnectionManager<IdleMode>()
            try await connection.connect()

            defer { Task { await connection.disconnect() } }

            return try await body(connection)
        }

        @Test
        func `The subsystems asked for are named as the protocol names them`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["changed: player"]),
            ]) { stub in
                _ = try await idling {
                    try await $0.idleForEvents(mask: [.player, .queue,
                                                      .playlists, .options,
                                                      .mixer, .output,
                                                      .database])
                }

                #expect(stub.lastCommands
                    == ["idle player playlist stored_playlist options mixer output database"])
            }
        }

        @Test
        func `Every subsystem that changed is reported`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["changed: player", "changed: mixer"]),
            ]) { _ in
                let events = try await idling {
                    try await $0.idleForEvents(mask: [.player, .mixer])
                }

                #expect(events == [.player, .mixer])
            }
        }

        @Test
        func `The queue and stored playlists are told apart`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["changed: playlist",
                               "changed: stored_playlist"]),
            ]) { _ in
                let events = try await idling {
                    try await $0.idleForEvents(mask: [.queue, .playlists])
                }

                #expect(events == [.queue, .playlists])
            }
        }

        @Test
        func `A subsystem MPDKit does not watch is passed over`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["changed: sticker", "changed: player"]),
            ]) { _ in
                let events = try await idling {
                    try await $0.idleForEvents(mask: [.player])
                }

                #expect(events == [.player])
            }
        }

        @Test
        func `A parked idle is cancelled by noidle, which answers it`() async throws {
            try await MPDStub.withServer(replies: [MPDStub.reply()],
                                         parksIdle: true)
            { stub in
                let connection = ConnectionManager<IdleMode>()
                try await connection.connect()

                async let events = connection.idleForEvents(mask: [.player])

                var isParked = await connection.isIdlePending
                var attempts = 0
                while !isParked, attempts < 200 {
                    try await Task.sleep(for: .milliseconds(5))
                    isParked = await connection.isIdlePending
                    attempts += 1
                }

                #expect(isParked)
                #expect(await connection.probe())
                #expect(try await events.isEmpty)
                #expect(stub.commands == [["idle player"], ["noidle"]])

                await connection.disconnect()
            }
        }

        @Test
        func `An idle that was cancelled reports no change`() async throws {
            try await MPDStub.withServer(replies: [MPDStub.reply()]) { _ in
                let events = try await idling {
                    try await $0.idleForEvents(mask: [.player])
                }

                #expect(events.isEmpty)
            }
        }
    }

    @Suite("Artwork")
    struct ArtworkTests {
        /// Four bytes standing in for an image.
        private static let payload = Data([0xFF, 0xD8, 0xFF, 0xE0])

        @Test
        func `The binary chunk limit is raised on a server that has it`() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.24.0") { stub in
                try await ConnectionManager<ArtworkMode>.artwork { _ in }

                #expect(stub.commands == [["binarylimit 131072"]])
            }
        }

        @Test
        func `A server without binarylimit is not asked to raise it`() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.22.0") { stub in
                try await ConnectionManager<ArtworkMode>.artwork { _ in }

                #expect(stub.requests.isEmpty)
            }
        }

        @Test
        func `Artwork is asked for from the offset reached so far`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.binary(Self.payload, file: "cover.jpg"),
            ]) { stub in
                let data = try await ConnectionManager<ArtworkMode>
                    .artwork { try await $0.getArtworkData(for: "a.flac") }

                #expect(data == Self.payload)
                #expect(stub.lastCommands == ["albumart \"a.flac\" 0"])
            }
        }

        @Test
        func `A picture longer than one chunk is read until its size is met`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.binary(Self.payload, size: 8),
                MPDStub.binary(Self.payload, size: 8),
            ]) { stub in
                let data = try await ConnectionManager<ArtworkMode>
                    .artwork { try await $0.getArtworkData(for: "a.flac") }

                #expect(data == Self.payload + Self.payload)
                #expect(stub.commands == [["binarylimit 131072"],
                                          ["albumart \"a.flac\" 0"],
                                          ["albumart \"a.flac\" 4"]])
            }
        }

        @Test
        func `A song with no cover beside it falls back to its own tags`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.failure(command: "albumart"),
                MPDStub.binary(Self.payload, type: "image/jpeg"),
            ]) { stub in
                let data = try await ConnectionManager<ArtworkMode>
                    .artwork { try await $0.getArtworkData(for: "a.flac") }

                #expect(data == Self.payload)
                #expect(stub.commands == [["binarylimit 131072"],
                                          ["albumart \"a.flac\" 0"],
                                          ["readpicture \"a.flac\" 0"]])
            }
        }

        @Test
        func `Embedded pictures are not asked of a server too old for them`() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.21.0",
                                         artworkGetter: .metadata)
            { stub in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<ArtworkMode>.artwork {
                        try await $0.getArtworkData(for: "a.flac")
                    }
                }

                #expect(stub.requests.isEmpty)
            }
        }

        @Test
        func `Nothing found anywhere is reported as no artwork`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.failure(command: "albumart"),
                MPDStub.failure(command: "readpicture"),
            ]) { _ in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<ArtworkMode>.artwork {
                        try await $0.getArtworkData(for: "a.flac")
                    }
                }
            }
        }

        /// The protocol says a song with no embedded picture answers
        /// successfully with an otherwise empty response, which is not a
        /// failure and so must not end the search.
        @Test
        func `A song with no embedded picture falls through to the next source`() async throws {
            try await MPDStub.withServer(
                replies: [MPDStub.reply(), MPDStub.reply(),
                          MPDStub.binary(Self.payload)],
                artworkGetter: .metadataThenLibrary,
            ) { stub in
                let data = try await ConnectionManager<ArtworkMode>
                    .artwork { try await $0.getArtworkData(for: "a.flac") }

                #expect(data == Self.payload)
                #expect(stub.commands == [["binarylimit 131072"],
                                          ["readpicture \"a.flac\" 0"],
                                          ["albumart \"a.flac\" 0"]])
            }
        }

        @Test
        func `A song no source has a picture for is reported as having none`() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                await #expect(throws: ConnectionManagerError
                    .malformedResponse("No artwork found"))
                {
                    try await ConnectionManager<ArtworkMode>.artwork {
                        try await $0.getArtworkData(for: "a.flac")
                    }
                }

                #expect(stub.commands == [["binarylimit 131072"],
                                          ["albumart \"a.flac\" 0"],
                                          ["readpicture \"a.flac\" 0"]])
            }
        }

        @Test
        func `A binary response that stops short of its size is malformed`() async throws {
            var truncated = Data("size: 8\nbinary: 4\n".utf8)
            truncated.append(Self.payload)
            truncated.append(0x0A)
            truncated.append(Data("OK\n".utf8))

            try await MPDStub.withServer(replies: [
                MPDStub.reply(), truncated, MPDStub.reply(),
            ]) { _ in
                await #expect(throws: ConnectionManagerError
                    .malformedResponse(
                        "Binary response ended before its stated size",
                    ))
                {
                    try await ConnectionManager<ArtworkMode>.artwork {
                        try await $0.getArtworkData(for: "a.flac")
                    }
                }
            }
        }
    }

    @Suite("Connection configuration")
    struct ConnectionConfigurationTests {
        @Test
        func `Selecting a server discards the previous one's tag list`() {
            defer { ConnectionConfiguration.server = nil }

            ConnectionConfiguration.availableTags = ["artist", "album"]
            ConnectionConfiguration.server = Server(host: "nas.local")

            #expect(ConnectionConfiguration.availableTags == nil)
        }

        @Test
        func `Deselecting a server discards its tag list too`() {
            ConnectionConfiguration.server = Server(host: "nas.local")
            ConnectionConfiguration.availableTags = ["artist"]
            ConnectionConfiguration.server = nil

            #expect(ConnectionConfiguration.availableTags == nil)
        }

        @Test
        func `The selected server is what a later reader sees`() {
            defer { ConnectionConfiguration.server = nil }

            ConnectionConfiguration.server = Server(name: "Living room",
                                                    host: "nas.local", port: 6601)

            #expect(ConnectionConfiguration.server?.host == "nas.local")
            #expect(ConnectionConfiguration.server?.port == 6601)
        }

        @Test
        func `Connecting without a server to connect to fails`() async {
            ConnectionConfiguration.server = nil

            await #expect(throws: ConnectionManagerError.invalidHost) {
                try await ConnectionManager<CommandMode>().connect()
            }
        }

        @Test
        func `Connecting to an empty host fails before any socket is opened`() async {
            defer { ConnectionConfiguration.server = nil }

            ConnectionConfiguration.server = Server(host: "")

            await #expect(throws: ConnectionManagerError.invalidHost) {
                try await ConnectionManager<CommandMode>().connect()
            }
        }

        @Test
        func `A port outside the range a socket has is rejected`() async {
            defer { ConnectionConfiguration.server = nil }

            for port in [0, -1, 65536, 70000] {
                ConnectionConfiguration.server = Server(host: "nas.local",
                                                        port: port)

                await #expect(throws: ConnectionManagerError.invalidPort) {
                    try await ConnectionManager<CommandMode>().connect()
                }
            }
        }

        @Test
        func `A rejected connection leaves the manager unconnected`() async {
            defer { ConnectionConfiguration.server = nil }

            ConnectionConfiguration.server = Server(host: "nas.local", port: 0)

            let connection = ConnectionManager<CommandMode>()

            _ = try? await connection.connect()

            #expect(await connection.version == nil)
            #expect(await connection.isCommandInFlight == false)
        }
    }
}
