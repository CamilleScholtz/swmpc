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
    @Test("The fractional duration is preferred when the server sends it")
    func prefersDuration() throws {
        let song = try Song.parse(
            fields: ["file": "a.flac", "duration": "245.533", "time": "245"],
            index: nil,
        )

        #expect(song.duration == 245.533)
    }

    @Test("Servers older than 0.20 fall back to the integer Time field")
    func fallsBackToTime() throws {
        let song = try Song.parse(
            fields: ["file": "a.flac", "time": "245"],
            index: nil,
        )

        #expect(song.duration == 245)
    }

    @Test("A song with neither field has no duration rather than failing")
    func missingDuration() throws {
        let song = try Song.parse(fields: ["file": "a.flac"], index: nil)

        #expect(song.duration == 0)
    }

    @Test("A response without a file is rejected")
    func missingFile() {
        #expect(throws: ConnectionManagerError.self) {
            try Song.parse(fields: ["title": "Orphan"], index: nil)
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

    @Test("Servers older than 0.21 omit the plugin and still yield an output")
    func withoutPlugin() throws {
        let output = try #require(Output([
            "outputid": "1", "outputname": "Speakers", "outputenabled": "0",
        ]))

        #expect(output.plugin == nil)
        #expect(!output.isHttpd)
        #expect(!output.isEnabled)
        #expect(output.name == "Speakers")
    }

    @Test("An output without an id or name is not an output")
    func incomplete() {
        #expect(Output(["outputname": "Nameless"]) == nil)
        #expect(Output(["outputid": "0"]) == nil)
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
}
