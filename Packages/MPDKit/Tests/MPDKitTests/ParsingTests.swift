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

    @Test("An output missing any required field is not an output")
    func incomplete() {
        #expect(Output(["outputname": "Nameless", "plugin": "alsa"]) == nil)
        #expect(Output(["outputid": "0", "plugin": "alsa"]) == nil)
        #expect(Output(["outputid": "0", "outputname": "No plugin"]) == nil)
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
