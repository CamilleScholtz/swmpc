//
//  SearchAndPlayIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit
import SwiftUI

enum SearchMediaKind: String, AppEnum {
    case anything
    case artist
    case album
    case song

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Media Type")

    static let caseDisplayRepresentations: [SearchMediaKind: DisplayRepresentation] = [
        .anything: DisplayRepresentation(title: "Anything"),
        .artist: DisplayRepresentation(title: "Artist"),
        .album: DisplayRepresentation(title: "Album"),
        .song: DisplayRepresentation(title: "Song"),
    ]
}

struct SearchAndPlayIntent: AppIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Search and Play"
    static let description = IntentDescription("Search the library for an artist, album, or song and play it")

    @Parameter(title: "Query", description: "The name to search for",
               requestValueDialog: "What do you want to play?")
    var query: String

    @Parameter(title: "Type", description: "The kind of media to search for",
               default: .anything)
    var kind: SearchMediaKind

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let match = try await findMatch() else {
            return .result(dialog: IntentDialog(stringLiteral: "Found nothing matching '\(query)'"))
        }

        try await command {
            try await $0.play(match)
        }

        let dialog = switch match {
        case let artist as Artist:
            "Playing songs by \(artist.name)"
        case let album as Album:
            "Playing \(album.title) by \(album.artist.name)"
        case let song as Song:
            "Playing \(song.title) by \(song.artist)"
        default:
            "Playing"
        }

        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }

    /// Finds the library item best matching the query.
    ///
    /// Albums and artists are cheap to fetch and are checked first; the full
    /// song list is only fetched when they yield nothing (or when searching
    /// for songs specifically). Within the fetched collections an exact title
    /// match in any of them beats a substring match in an earlier one.
    private func findMatch() async throws -> (any Mediable)? {
        var collections: [[any Mediable]] = []

        if kind == .anything || kind == .album {
            try await collections.append(command {
                try await $0.getAlbums()
            })
        }
        if kind == .anything || kind == .artist {
            try await collections.append(command {
                try await $0.getArtists()
            })
        }

        if let match = match(in: collections) {
            return match
        }

        guard kind == .anything || kind == .song else {
            return nil
        }

        let songs = try await command {
            try await $0.getSongs(from: Source.database)
        }

        return match(in: [songs])
    }

    private func match(in collections: [[any Mediable]]) -> (any Mediable)? {
        for collection in collections {
            if let item = collection.first(where: { matches($0, exactly: true) }) {
                return item
            }
        }

        for collection in collections {
            if let item = collection.first(where: { matches($0, exactly: false) }) {
                return item
            }
        }

        return nil
    }

    private func matches(_ item: any Mediable, exactly: Bool) -> Bool {
        let names: [String?] = switch item {
        case let album as Album:
            [album.title, album.titleSort]
        case let artist as Artist:
            [artist.name, artist.nameSort]
        case let song as Song:
            [song.title, song.titleSort]
        default:
            []
        }

        let query = query.folded

        return names.compactMap(\.self).contains {
            exactly ? $0.folded == query : $0.folded.contains(query)
        }
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Search for \(\.$query) and play \(\.$kind)")
    }
}
