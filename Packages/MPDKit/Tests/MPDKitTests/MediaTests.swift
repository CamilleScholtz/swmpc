//
//  MediaTests.swift
//  MPDKit
//
//  Created by Camille Scholtz on 01/09/2026.
//

import Foundation
import Testing

@testable import MPDKit

/// Builds an artist, since only the name distinguishes one.
private func artist(_ name: String, sort: String? = nil,
                    file: String = "a.flac") -> Artist
{
    Artist(file: file, name: name, nameSort: sort)
}

/// Builds an album, since only the artist and title distinguish one.
private func album(_ title: String, by name: String = "Radiohead",
                   file: String = "a.flac") -> Album
{
    Album(file: file, title: title, titleSort: nil,
          artist: artist(name, file: file))
}

/// Builds a song carrying just enough to be placed in an album.
private func song(_ file: String, title: String = "Idioteque",
                  by name: String = "Radiohead",
                  on albumTitle: String = "Kid A",
                  position: UInt32? = nil, identifier: UInt32? = nil,
                  disc: Int = 1, track: Int = 1) -> Song
{
    Song(
        file: file, identifier: identifier, position: position, artist: name,
        artistSort: nil, title: title, titleSort: nil, duration: 0,
        disc: disc, track: track, genre: nil, composer: nil, performer: nil,
        conductor: nil, ensemble: nil, mood: nil, comment: nil,
        album: album(albumTitle, by: name, file: file),
    )
}

@Suite("Album identity")
struct AlbumIdentityTests {
    @Test("An album is identified by its artist and title together")
    func identifier() {
        #expect(album("Kid A").id == "Radiohead - Kid A")
        #expect(album("Kid A").description == "Radiohead - Kid A")
    }

    @Test("The same release found through a different file is the same album")
    func equalityIgnoresFile() {
        let first = album("Kid A", file: "a.flac")
        let second = album("Kid A", file: "b.flac")

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
        #expect(Set([first, second]).count == 1)
    }

    @Test("Albums of the same name by different artists stay apart")
    func equalityRespectsArtist() {
        #expect(album("Greatest Hits", by: "Queen")
            != album("Greatest Hits", by: "ABBA"))
        #expect(album("Kid A") != album("Amnesiac"))
    }

    @Test("The identifier survives a round trip, though it is never encoded")
    func codable() throws {
        let original = Album(file: "a.flac", title: "Kid A",
                             titleSort: "Kid A",
                             artist: artist("Radiohead", sort: "Radiohead"))
        let decoded = try JSONDecoder()
            .decode(Album.self, from: JSONEncoder().encode(original))

        #expect(decoded == original)
        #expect(decoded.id == "Radiohead - Kid A")
        #expect(decoded.titleSort == "Kid A")
        #expect(decoded.artist.nameSort == "Radiohead")
    }

    @Test("An encoded album carries no identifier of its own")
    func decodesWithoutIdentifier() throws {
        let json = """
        {"file": "a.flac", "title": "Kid A",
         "artist": {"file": "a.flac", "name": "Radiohead"}}
        """

        let decoded = try JSONDecoder().decode(Album.self,
                                               from: Data(json.utf8))

        #expect(decoded.id == "Radiohead - Kid A")
        #expect(decoded.titleSort == nil)
    }
}

@Suite("Artist identity")
struct ArtistIdentityTests {
    @Test("An artist is identified by name alone")
    func identifier() {
        #expect(artist("Radiohead").id == "Radiohead")
    }

    @Test("The same name found through a different file is the same artist")
    func equalityIgnoresFile() {
        let first = artist("Radiohead", file: "a.flac")
        let second = artist("Radiohead", sort: "Radiohead", file: "b.flac")

        #expect(first == second)
        #expect(first.hashValue == second.hashValue)
    }

    @Test("Different names are different artists")
    func equalityRespectsName() {
        #expect(artist("Radiohead") != artist("Thom Yorke"))
    }

    @Test("An artist survives a round trip")
    func codable() throws {
        let original = artist("The Beatles", sort: "Beatles, The")
        let decoded = try JSONDecoder()
            .decode(Artist.self, from: JSONEncoder().encode(original))

        #expect(decoded == original)
        #expect(decoded.nameSort == "Beatles, The")
    }
}

@Suite("Song identity")
struct SongIdentityTests {
    @Test("A song is identified by its path")
    func identifier() {
        #expect(song("music/a.flac").id == "music/a.flac")
        #expect(song("music/a.flac").description == "Radiohead - Idioteque")
    }

    @Test("The same file in the queue and the database is the same song")
    func equalityIgnoresPlacement() {
        let queued = song("a.flac", position: 3, identifier: 9)
        let stored = song("a.flac")

        #expect(queued == stored)
        #expect(queued.hashValue == stored.hashValue)
    }

    @Test("Songs know the album and artist they belong to")
    func membership() {
        let track = song("a.flac", by: "Radiohead", on: "Kid A")

        #expect(track.isIn(album("Kid A", by: "Radiohead")))
        #expect(!track.isIn(album("Amnesiac", by: "Radiohead")))
        #expect(track.isBy(artist("Radiohead")))
        #expect(!track.isBy(artist("Thom Yorke")))
    }

    @Test("Membership follows the album artist, not the performing one")
    func membershipUsesAlbumArtist() throws {
        let track = try Song.parse(
            fields: ["file": "a.flac", "artist": "Kanye West",
                     "albumartist": "Various Artists", "album": "Compilation"],
            index: nil,
        )

        #expect(track.isBy(artist("Various Artists")))
        #expect(!track.isBy(artist("Kanye West")))
    }

    @Test("A song survives a round trip, album and all")
    func codable() throws {
        let original = song("a.flac", position: 2, identifier: 7, disc: 2,
                            track: 11)
        let decoded = try JSONDecoder()
            .decode(Song.self, from: JSONEncoder().encode(original))

        #expect(decoded == original)
        #expect(decoded.position == 2)
        #expect(decoded.identifier == 7)
        #expect(decoded.disc == 2)
        #expect(decoded.track == 11)
        #expect(decoded.album == original.album)
    }

    @Test("Sorting by disc then track puts a multi-disc album in order")
    func discAndTrackOrdering() {
        let songs = [
            song("d2t1.flac", disc: 2, track: 1),
            song("d1t2.flac", disc: 1, track: 2),
            song("d1t10.flac", disc: 1, track: 10),
            song("d1t1.flac", disc: 1, track: 1),
        ]

        let sorted = songs.sorted { ($0.disc, $0.track) < ($1.disc, $1.track) }

        #expect(sorted.map(\.file)
            == ["d1t1.flac", "d1t2.flac", "d1t10.flac", "d2t1.flac"])
    }
}

@Suite("Playlists")
struct PlaylistTests {
    @Test("A playlist is identified by its name")
    func identifier() {
        #expect(Playlist(name: "Favorites").id == "Favorites")
    }

    @Test("The symbol is metadata, and never part of identity")
    func equalityIgnoresSymbol() {
        let plain = Playlist(name: "Focus")
        let decorated = Playlist(name: "Focus", symbolName: "brain")

        #expect(plain == decorated)
        #expect(plain.hashValue == decorated.hashValue)
        #expect(Set([plain, decorated]).count == 1)
    }

    @Test("Different names are different playlists")
    func equalityRespectsName() {
        #expect(Playlist(name: "Focus") != Playlist(name: "Sleep"))
    }

    @Test("A playlist survives a round trip, symbol and all")
    func codable() throws {
        let original = Playlist(name: "Focus", symbolName: "brain")
        let decoded = try JSONDecoder()
            .decode(Playlist.self, from: JSONEncoder().encode(original))

        #expect(decoded == original)
        #expect(decoded.symbolName == "brain")
    }
}

@Suite("Servers")
struct ServerTests {
    @Test("A server without a name shows its host instead")
    func displayName() {
        #expect(Server(host: "nas.local").displayName == "nas.local")
        #expect(Server(name: "Living room", host: "nas.local").displayName
            == "Living room")
    }

    @Test("A server that is not streaming has no stream to play")
    func withoutStream() {
        #expect(Server(host: "nas.local").streamURL == nil)
    }

    @Test("The stream URL is built from the host and the streaming port")
    func streamURL() {
        let server = Server(host: "nas.local", streamingPort: 8000)

        #expect(server.streamURL?.absoluteString == "http://nas.local:8000/")
    }

    @Test("The defaults point at a local server on the protocol's port")
    func defaults() {
        let server = Server()

        #expect(server.host == "localhost")
        #expect(server.port == 6600)
        #expect(server.password.isEmpty)
        #expect(server.artworkGetter == .libraryThenMetadata)
        #expect(server.streamingPort == nil)
    }

    @Test("A server survives a round trip, identity and all")
    func codable() throws {
        let original = Server(name: "Living room", host: "nas.local",
                              port: 6601, password: "hunter2",
                              artworkGetter: .metadata, streamingPort: 8000)
        let decoded = try JSONDecoder()
            .decode(Server.self, from: JSONEncoder().encode(original))

        #expect(decoded == original)
        #expect(decoded.id == original.id)
        #expect(decoded.artworkGetter == .metadata)
        #expect(decoded.streamingPort == 8000)
    }

    @Test("Two servers configured alike are still two servers")
    func identity() {
        #expect(Server(host: "nas.local") != Server(host: "nas.local"))
    }
}

@Suite("Outputs")
struct OutputTests {
    @Test("An output is identified by the number the server gave it")
    func identifier() {
        let output = Output(id: 3, name: "Speakers", plugin: "alsa",
                            isEnabled: true)

        #expect(output.id == 3)
        #expect(output.attributes.isEmpty)
    }

    @Test("Toggling an output changes it")
    func equality() {
        let enabled = Output(id: 0, name: "Speakers", plugin: "alsa",
                             isEnabled: true)
        let disabled = Output(id: 0, name: "Speakers", plugin: "alsa",
                              isEnabled: false)

        #expect(enabled != disabled)
        #expect(enabled == Output(id: 0, name: "Speakers", plugin: "alsa",
                                  isEnabled: true))
    }

    @Test("Only the httpd plugin is a stream")
    func httpd() {
        #expect(Output(id: 0, name: "Stream", plugin: "httpd",
                       isEnabled: true).isHttpd)
        #expect(!Output(id: 0, name: "Speakers", plugin: "pulse",
                        isEnabled: true).isHttpd)
    }
}
