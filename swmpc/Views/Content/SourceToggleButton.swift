//
//  SourceToggleButton.swift
//  swmpc
//
//  Created by Camille Scholtz on 28/06/2025.
//

import ButtonKit
import SwiftUI

struct SourceToggleButton<Media: Mediable>: View {
    @Environment(MPD.self) private var mpd

    let media: Media
    let source: Source

    @State private var songs: [Song]?

    private var mediaTypeName: String {
        switch media {
        case is Album: "Album"
        case is Artist: "Artist"
        case is Song: "Song"
        default: ""
        }
    }

    private var sourceName: String {
        switch source {
        case .queue: "Queue"
        case .favorites: "Favorites"
        case let .playlist(playlist): playlist.name
        default: ""
        }
    }

    private var inSource: Bool {
        guard let songs else {
            return false
        }

        let urls: Set<URL>
        switch source {
        case .queue:
            urls = Set(mpd.queue.internalMedia.map(\.url))
        case .favorites:
            urls = Set(mpd.playlists.favorites.map(\.url))
        case .playlist:
            return false
        default:
            return false
        }

        return songs.contains { urls.contains($0.url) }
    }

    var body: some View {
        AsyncButton(inSource ? "Remove \(mediaTypeName) from \(sourceName)" : "Add \(mediaTypeName) to \(sourceName)") {
            guard let songs else {
                throw ViewError.missingData
            }

            if inSource {
                try await ConnectionManager.command().remove(songs: songs, from: source)
            } else {
                try await ConnectionManager.command().add(songs: songs, to: source)
            }
        }
        .disabled(songs == nil)
        .task(id: media) {
            switch media {
            case let album as Album:
                songs = try? await ConnectionManager.command().getSongs(in: album, from: .database)
            case let artist as Artist:
                songs = try? await ConnectionManager.command().getSongs(by: artist, from: .database)
            case let song as Song:
                songs = [song]
            default:
                songs = nil
            }
        }
    }
}
