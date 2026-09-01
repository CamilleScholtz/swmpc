//
//  ProtocolConformanceTests.swift
//  MPDKit
//
//  Created by Camille Scholtz on 01/09/2026.
//

import Foundation
import Testing

@testable import MPDKit

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
        @Test("The greeting names the protocol version commands are gated on")
        func greeting() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.24.0") { _ in
                let version = try await ConnectionManager<CommandMode>
                    .command { await $0.version }

                #expect(version == "0.24.0")
            }
        }

        @Test("A server below the supported floor is turned away")
        func belowFloor() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.19.0") { _ in
                await #expect(throws: ConnectionManagerError
                    .unsupportedServerVersion)
                {
                    try await ConnectionManager<CommandMode>.command { _ in }
                }
            }
        }

        @Test("A server at the floor is accepted")
        func atFloor() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.21.0") { _ in
                let version = try await ConnectionManager<CommandMode>
                    .command { await $0.version }

                #expect(version == "0.21.0")
            }
        }

        @Test("Anything but the documented greeting is refused")
        func withoutGreeting() async throws {
            try await MPDStub.withServer(greeting: "OK") { _ in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command { _ in }
                }
            }
        }

        @Test("A configured password is sent, quoted, before anything else")
        func password() async throws {
            try await MPDStub.withServer(password: "hunter2") { stub in
                try await ConnectionManager<CommandMode>.command { _ in }

                #expect(stub.requests == [["password \"hunter2\""]])
            }
        }

        @Test("A password with protocol punctuation in it is escaped")
        func awkwardPassword() async throws {
            try await MPDStub.withServer(password: "say \"hi\"\\") { stub in
                try await ConnectionManager<CommandMode>.command { _ in }

                #expect(stub.requests == [["password \"say \\\"hi\\\"\\\\\""]])
            }
        }

        @Test("Without a password nothing is sent before the first command")
        func withoutPassword() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command { _ in }

                #expect(stub.requests.isEmpty)
            }
        }

        @Test("A manager serves one connection and will not open a second")
        func singleUse() async throws {
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
        @Test("A single command is sent on its own line")
        func singleCommand() async throws {
            try await MPDStub.withServer { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.run(["status"])
                }

                #expect(stub.requests == [["status"]])
            }
        }

        @Test("Several commands are wrapped in a command list")
        func commandList() async throws {
            try await MPDStub.withServer { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.run(["clear", "add /", "play"])
                }

                #expect(stub.requests == [["command_list_begin", "clear",
                                           "add /", "play",
                                           "command_list_end"]])
            }
        }

        @Test("A command list answers as one response, ending in a single OK")
        func commandListResponse() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["volume: 42", "state: play"]),
            ]) { _ in
                let lines = try await ConnectionManager<CommandMode>.command {
                    try await $0.run(["status", "currentsong"])
                }

                #expect(lines == ["volume: 42", "state: play", "OK"])
            }
        }

        @Test("An ACK is a protocol violation carrying the server's words")
        func acknowledgedError() async throws {
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

        @Test("A server that hangs up mid-command is reported, not awaited")
        func hangUp() async throws {
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

        @Test("Status and the current song are asked for in one round trip")
        func request() async throws {
            try await MPDStub.withServer(replies: [Self.full]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getStatusData()
                }

                #expect(stub.lastCommands == ["status", "currentsong"])
            }
        }

        @Test("Every status field MPDKit reads is read")
        func fields() async throws {
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

        @Test("Each documented player state is understood")
        func states() async throws {
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

        @Test("A state the protocol does not define is malformed")
        func unknownState() async throws {
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

        @Test("A stopped player reports no current song")
        func stopped() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["state: stop", "volume: 0"]),
            ]) { _ in
                let status = try await ConnectionManager<CommandMode>
                    .command { try await $0.getStatusData() }

                #expect(status.state == .stop)
                #expect(status.song == nil)
            }
        }

        @Test("Fields the server left out are left unknown")
        func missingFields() async throws {
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

        @Test("A server with no mixer reports its volume as minus one")
        func withoutMixer() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["state: play", "volume: -1"]),
            ]) { _ in
                let status = try await ConnectionManager<CommandMode>
                    .command { try await $0.getStatusData() }

                #expect(status.volume == -1)
            }
        }

        @Test("The one-shot modes MPD 0.24 added read as off, not on")
        func oneShot() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["state: play", "consume: oneshot",
                               "single: oneshot"]),
            ]) { _ in
                let status = try await ConnectionManager<CommandMode>
                    .command { try await $0.getStatusData() }

                #expect(status.isConsume == false)
            }
        }

        @Test("A DSD stream reports a rate and channels but no bit depth")
        func dsd() async throws {
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
        @Test("Statistics are asked for with one command")
        func request() async throws {
            try await MPDStub.withServer(replies: [MPDStub.reply()]) { stub in
                _ = try await ConnectionManager<CommandMode>.command {
                    try await $0.getStatsData()
                }

                #expect(stub.lastCommands == ["stats"])
            }
        }

        @Test("Every documented statistic MPDKit reads is read")
        func fields() async throws {
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
        @Test("The protocol's own escaping example goes out as documented")
        func documentedExample() async throws {
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

        @Test("A backslash is doubled twice over, for value and for protocol")
        func backslashes() async throws {
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

        @Test("A newline cannot ride along on a line-based protocol")
        func newlines() async throws {
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

        @Test("Values outside ASCII survive both ways, as UTF-8")
        func unicode() async throws {
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

        @Test("A response line that is not UTF-8 is malformed")
        func invalidEncoding() async throws {
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

        @Test("A quoted argument keeps its spaces in one argument")
        func spaces() async throws {
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
        @Test("Albums are found through the first track of each")
        func albums() async throws {
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

        @Test("An album found twice is listed once")
        func albumsAreUnique() async throws {
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

        @Test("The sort argument carries the descriptor asked for")
        func albumSort() async throws {
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

        @Test("An artist's albums are found by album artist, in release order")
        func albumsByArtist() async throws {
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

        @Test("The queue is sorted only on a server whose playlistfind can")
        func albumsByArtistInQueue() async throws {
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

        @Test("Only the database and the queue can be asked for an artist")
        func albumsByArtistElsewhere() async throws {
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

        @Test("Artists and their album counts come from the album listing")
        func artists() async throws {
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

        @Test("Each source is read with the command the protocol gives it")
        func songSources() async throws {
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

        @Test("Songs from a list are numbered when the server gives no position")
        func songPositions() async throws {
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

        @Test("A position the queue reported is kept as the queue's own")
        func queuePositions() async throws {
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

        @Test("An album's songs are asked for with one conjoined filter")
        func songsInAlbum() async throws {
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

        @Test("An album's songs come back by disc and then by track")
        func albumOrdering() async throws {
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

        @Test("The queue keeps its own order, whatever the tags say")
        func queueOrdering() async throws {
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

        @Test("An artist's songs come back album by album, each in order")
        func songsByArtist() async throws {
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

        @Test("Playlists are listed by name, ignoring their timestamps")
        func playlists() async throws {
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

        @Test("Outputs are listed with the fields the protocol names")
        func outputs() async throws {
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

        @Test("The mask is set and put back inside the query's own list")
        func narrows() async throws {
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

        @Test("The server is asked what it supports once, then remembered")
        func caches() async throws {
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

        @Test("A server that names no tags is queried without a mask")
        func withoutTagTypes() async throws {
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

        @Test("A server that names no tags is not asked a second time")
        func remembersSilence() async throws {
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

        @Test("A query that fails takes the mask off again")
        func restoresAfterFailure() async throws {
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

        @Test("Only songs the queue has not got are added")
        func addsMissingSongs() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)),
                MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.add(songs: [self.song("a.flac"),
                                             self.song("b.flac")],
                                     to: .queue)
                }

                #expect(stub.lastCommands == ["add \"b.flac\""])
            }
        }

        @Test("Adding nothing new sends nothing at all")
        func addsNothing() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.add(songs: [self.song("a.flac")], to: .queue)
                }

                #expect(stub.commands.last != ["add \"a.flac\""])
                #expect(stub.requests.count == 2)
            }
        }

        @Test("A playlist is added to by name, song by song")
        func addsToPlaylist() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(), MPDStub.reply(), MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.add(songs: [self.song("a.flac"),
                                             self.song("b.flac")],
                                     to: .playlist(Playlist(name: "Focus")))
                }

                #expect(stub.lastCommands == ["playlistadd \"Focus\" \"a.flac\"",
                                              "playlistadd \"Focus\" \"b.flac\""])
            }
        }

        @Test("The database cannot be added to, and is not read to find out")
        func cannotAddToDatabase() async throws {
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

        @Test("The database cannot be removed from either")
        func cannotRemoveFromDatabase() async throws {
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

        @Test("A run of queue positions is deleted as one half-open range")
        func deletesRange() async throws {
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
                    try await $0.remove(songs: [self.song("b.flac"),
                                                self.song("c.flac"),
                                                self.song("d.flac")],
                                        from: .queue)
                }

                #expect(stub.lastCommands == ["delete 1:4"])
            }
        }

        @Test("A single position is deleted by position alone")
        func deletesOne() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)
                    + MPDStub.song("b.flac", position: 1)),
                MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.remove(songs: [self.song("b.flac")],
                                        from: .queue)
                }

                #expect(stub.lastCommands == ["delete 1"])
            }
        }

        @Test("Scattered positions are deleted from the back forwards")
        func deletesScattered() async throws {
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
                    try await $0.remove(songs: [self.song("e.flac"),
                                                self.song("c.flac")],
                                        from: .queue)
                }

                #expect(stub.lastCommands == ["delete 4", "delete 2"])
            }
        }

        @Test("A playlist is deleted from one position at a time, descending")
        func deletesFromPlaylist() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)
                    + MPDStub.song("b.flac", position: 1)
                    + MPDStub.song("c.flac", position: 2)),
                MPDStub.reply(),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.remove(songs: [self.song("b.flac"),
                                                self.song("c.flac")],
                                        from: .playlist(
                                            Playlist(name: "Focus"),
                                        ))
                }

                #expect(stub.lastCommands == ["playlistdelete \"Focus\" 2",
                                              "playlistdelete \"Focus\" 1"])
            }
        }

        @Test("Removing songs the source has not got sends nothing")
        func removesNothing() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(),
                MPDStub.reply(MPDStub.song("a.flac", position: 0)),
            ]) { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.remove(songs: [self.song("z.flac")],
                                        from: .queue)
                }

                #expect(stub.requests.count == 2)
            }
        }

        @Test("A move names where the song is now and where it should go")
        func moves() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.move(self.song("a.flac", position: 3),
                                      to: 1, in: .queue)
                    try await $0.move(self.song("a.flac", position: 3),
                                      to: 1,
                                      in: .playlist(Playlist(name: "Focus")))
                }

                #expect(stub.commands.flatMap { $0 }
                    == ["move 3 1", "playlistmove \"Focus\" 3 1"])
            }
        }

        @Test("A song that is nowhere cannot be moved")
        func movesWithoutPosition() async throws {
            try await MPDStub.withServer { _ in
                await #expect(throws: ConnectionManagerError.self) {
                    try await ConnectionManager<CommandMode>.command {
                        try await $0.move(self.song("a.flac"), to: 1,
                                          in: .queue)
                    }
                }
            }
        }

        @Test("A queued song is played by the identity the queue gave it")
        func playsQueuedSong() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.play(self.song("a.flac", position: 0,
                                                identifier: 9))
                }

                #expect(stub.lastCommands == ["playid 9"])
            }
        }

        @Test("An album is queued with addid, then played by the id given back")
        func playsAlbum() async throws {
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

        @Test("An album already in the queue is played where it stands")
        func playsAlbumInQueue() async throws {
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

        @Test("An album with no songs behind it cannot be played")
        func playsNothing() async throws {
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
        @Test("Loading a playlist replaces the queue and starts it")
        func loads() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.loadPlaylist(Playlist(name: "Focus"))
                }

                #expect(stub.lastCommands
                    == ["clear", "load \"Focus\"", "play"])
            }
        }

        @Test("Loading everything adds the whole music directory")
        func loadsEverything() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.loadPlaylist()
                }

                #expect(stub.lastCommands == ["clear", "add /", "play"])
            }
        }

        @Test("A new playlist is saved and then emptied")
        func creates() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.createPlaylist(named: "Focus")
                }

                #expect(stub.commands == [["save \"Focus\""],
                                          ["playlistclear \"Focus\""]])
            }
        }

        @Test("A playlist that cannot be emptied is taken away again")
        func createRollback() async throws {
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

        @Test("Renaming and removing name the playlist as the protocol does")
        func renamesAndRemoves() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.renamePlaylist(Playlist(name: "Focus"),
                                                to: "Deep focus")
                    try await $0.removePlaylist(Playlist(name: "Sleep"))
                }

                #expect(stub.commands.flatMap { $0 }
                    == ["rename \"Focus\" \"Deep focus\"", "rm \"Sleep\""])
            }
        }
    }

    @Suite("Playback and options")
    struct PlaybackTests {
        @Test("Every command is spelled the way the protocol spells it")
        func commands() async throws {
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

                #expect(stub.commands.flatMap { $0 } == [
                    "pause 1", "pause 0", "previous", "next", "stop",
                    "consume 1", "random 0", "repeat 1", "seekcur 12.5",
                    "setvol 80", "clear", "toggleoutput 3",
                ])
            }
        }

        @Test("A database update rescans only when forced to")
        func updates() async throws {
            try await MPDStub.withServer { stub in
                try await ConnectionManager<CommandMode>.command {
                    try await $0.update()
                    try await $0.update(force: true)
                }

                #expect(stub.commands.flatMap { $0 } == ["update", "rescan"])
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

        @Test("The subsystems asked for are named as the protocol names them")
        func mask() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["changed: player"]),
            ]) { stub in
                _ = try await self.idling {
                    try await $0.idleForEvents(mask: [.player, .queue,
                                                      .playlists, .options,
                                                      .mixer, .output,
                                                      .database])
                }

                #expect(stub.lastCommands
                    == ["idle player playlist stored_playlist options mixer output database"])
            }
        }

        @Test("Every subsystem that changed is reported")
        func events() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["changed: player", "changed: mixer"]),
            ]) { _ in
                let events = try await self.idling {
                    try await $0.idleForEvents(mask: [.player, .mixer])
                }

                #expect(events == [.player, .mixer])
            }
        }

        @Test("The queue and stored playlists are told apart")
        func queueAndPlaylists() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["changed: playlist",
                               "changed: stored_playlist"]),
            ]) { _ in
                let events = try await self.idling {
                    try await $0.idleForEvents(mask: [.queue, .playlists])
                }

                #expect(events == [.queue, .playlists])
            }
        }

        @Test("A subsystem MPDKit does not watch is passed over")
        func unknownSubsystem() async throws {
            try await MPDStub.withServer(replies: [
                MPDStub.reply(["changed: sticker", "changed: player"]),
            ]) { _ in
                let events = try await self.idling {
                    try await $0.idleForEvents(mask: [.player])
                }

                #expect(events == [.player])
            }
        }

        @Test("A parked idle is cancelled by noidle, which answers it")
        func noidle() async throws {
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

        @Test("An idle that was cancelled reports no change")
        func cancelled() async throws {
            try await MPDStub.withServer(replies: [MPDStub.reply()]) { _ in
                let events = try await self.idling {
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

        @Test("The binary chunk limit is raised on a server that has it")
        func raisesLimit() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.24.0") { stub in
                try await ConnectionManager<ArtworkMode>.artwork { _ in }

                #expect(stub.commands == [["binarylimit 131072"]])
            }
        }

        @Test("A server without binarylimit is not asked to raise it")
        func withoutLimit() async throws {
            try await MPDStub.withServer(greeting: "OK MPD 0.22.0") { stub in
                try await ConnectionManager<ArtworkMode>.artwork { _ in }

                #expect(stub.requests.isEmpty)
            }
        }

        @Test("Artwork is asked for from the offset reached so far")
        func fetches() async throws {
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

        @Test("A picture longer than one chunk is read until its size is met")
        func fetchesChunks() async throws {
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

        @Test("A song with no cover beside it falls back to its own tags")
        func fallsBack() async throws {
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

        @Test("Embedded pictures are not asked of a server too old for them")
        func withoutReadPicture() async throws {
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

        @Test("Nothing found anywhere is reported as no artwork")
        func nothingFound() async throws {
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
        @Test("A song with no embedded picture falls through to the next source")
        func emptyPictureResponse() async throws {
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

        @Test("A song no source has a picture for is reported as having none")
        func noPictureAnywhere() async throws {
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

        @Test("A binary response that stops short of its size is malformed")
        func truncated() async throws {
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
        @Test("Selecting a server discards the previous one's tag list")
        func selectingServerClearsTags() {
            defer { ConnectionConfiguration.server = nil }

            ConnectionConfiguration.availableTags = ["artist", "album"]
            ConnectionConfiguration.server = Server(host: "nas.local")

            #expect(ConnectionConfiguration.availableTags == nil)
        }

        @Test("Deselecting a server discards its tag list too")
        func deselectingServerClearsTags() {
            ConnectionConfiguration.server = Server(host: "nas.local")
            ConnectionConfiguration.availableTags = ["artist"]
            ConnectionConfiguration.server = nil

            #expect(ConnectionConfiguration.availableTags == nil)
        }

        @Test("The selected server is what a later reader sees")
        func storesServer() {
            defer { ConnectionConfiguration.server = nil }

            ConnectionConfiguration.server = Server(name: "Living room",
                                                    host: "nas.local", port: 6601)

            #expect(ConnectionConfiguration.server?.host == "nas.local")
            #expect(ConnectionConfiguration.server?.port == 6601)
        }

        @Test("Connecting without a server to connect to fails")
        func withoutServer() async {
            ConnectionConfiguration.server = nil

            await #expect(throws: ConnectionManagerError.invalidHost) {
                try await ConnectionManager<CommandMode>().connect()
            }
        }

        @Test("Connecting to an empty host fails before any socket is opened")
        func emptyHost() async {
            defer { ConnectionConfiguration.server = nil }

            ConnectionConfiguration.server = Server(host: "")

            await #expect(throws: ConnectionManagerError.invalidHost) {
                try await ConnectionManager<CommandMode>().connect()
            }
        }

        @Test("A port outside the range a socket has is rejected")
        func invalidPort() async {
            defer { ConnectionConfiguration.server = nil }

            for port in [0, -1, 65536, 70000] {
                ConnectionConfiguration.server = Server(host: "nas.local",
                                                        port: port)

                await #expect(throws: ConnectionManagerError.invalidPort) {
                    try await ConnectionManager<CommandMode>().connect()
                }
            }
        }

        @Test("A rejected connection leaves the manager unconnected")
        func failureLeavesNothingBehind() async {
            defer { ConnectionConfiguration.server = nil }

            ConnectionConfiguration.server = Server(host: "nas.local", port: 0)

            let connection = ConnectionManager<CommandMode>()

            _ = try? await connection.connect()

            #expect(await connection.version == nil)
            #expect(await connection.isCommandInFlight == false)
        }
    }
}
