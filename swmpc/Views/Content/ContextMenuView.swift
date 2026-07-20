//
//  ContextMenuView.swift
//  swmpc
//
//  Created by Camille Scholtz on 30/06/2025.
//

import ButtonKit
import MPDKit
import SFSafeSymbols
import SwiftUI

struct ContextMenuView<Media: Mediable>: View {
    @Environment(MPD.self) private var mpd

    let media: Media
    let source: Source

    init(for media: Media, source: Source? = nil) {
        self.media = media
        self.source = source ?? .database
    }

    private var copyTitle: String {
        switch media {
        case is Song:
            String(localized: "Copy Song Title")
        case is Album:
            String(localized: "Copy Album Title")
        case is Artist:
            String(localized: "Copy Artist Name")
        default:
            String(localized: "Copy Title")
        }
    }

    private var textToCopy: String {
        switch media {
        case let song as Song:
            song.title
        case let album as Album:
            album.title
        case let artist as Artist:
            artist.name
        default:
            ""
        }
    }

    private var playlistMenuTitle: String {
        switch media {
        case is Song: String(localized: "Add or Remove Song from Playlist")
        case is Album: String(localized: "Add or Remove Album from Playlist")
        case is Artist: String(localized: "Add or Remove Artist from Playlist")
        default: ""
        }
    }

    var body: some View {
        if source != .database {
            SourceToggleButton(media: media, source: source, forceRemove: true)
        } else {
            SourceToggleButton(media: media, source: .queue)
        }

        Divider()

        if source != .queue, source != .database {
            SourceToggleButton(media: media, source: .queue)
        }

        if source != .favorites {
            SourceToggleButton(media: media, source: .favorites)
        }

        if let playlists = mpd.playlists.playlists {
            Menu(playlistMenuTitle, systemImage: SFSymbol.musicNoteList.rawValue) {
                ForEach(playlists) { playlist in
                    let shouldSkip = if case let .playlist(currentPlaylist) = source {
                        currentPlaylist == playlist
                    } else {
                        false
                    }

                    if !shouldSkip {
                        SourceToggleButton(media: media, source: .playlist(playlist), title: playlist.name)
                    }
                }
            }
        }

        Divider()

        Button(copyTitle, systemSymbol: .documentOnDocument) {
            textToCopy.copyToClipboard()
        }
    }
}

private struct SourceToggleButton<Media: Mediable>: View {
    @Environment(MPD.self) private var mpd

    let media: Media
    let source: Source
    var forceRemove = false
    var title: String?

    private var symbol: SFSymbol {
        switch source {
        case .queue:
            forceRemove ? .minusCircle : .musicNoteList
        case .favorites:
            .heart
        case let .playlist(playlist):
            playlist.symbol
        default:
            .plusCircle
        }
    }

    private var computedTitle: String {
        guard title == nil else {
            return title!
        }

        return switch (media, source, forceRemove) {
        case (is Song, .queue, false): String(localized: "Add or Remove Song from Queue")
        case (is Song, .queue, true): String(localized: "Remove Song from Queue")
        case (is Song, .favorites, false): String(localized: "Add or Remove Song from Favorites")
        case (is Song, .favorites, true): String(localized: "Remove Song from Favorites")
        case (is Song, .playlist, false): String(localized: "Add or Remove Song from Playlist")
        case (is Song, .playlist, true): String(localized: "Remove Song from Playlist")
        case (is Album, .queue, false): String(localized: "Add or Remove Album from Queue")
        case (is Album, .queue, true): String(localized: "Remove Album from Queue")
        case (is Album, .favorites, false): String(localized: "Add or Remove Album from Favorites")
        case (is Album, .favorites, true): String(localized: "Remove Album from Favorites")
        case (is Album, .playlist, false): String(localized: "Add or Remove Album from Playlist")
        case (is Album, .playlist, true): String(localized: "Remove Album from Playlist")
        case (is Artist, .queue, false): String(localized: "Add or Remove Artist from Queue")
        case (is Artist, .queue, true): String(localized: "Remove Artist from Queue")
        case (is Artist, .favorites, false): String(localized: "Add or Remove Artist from Favorites")
        case (is Artist, .favorites, true): String(localized: "Remove Artist from Favorites")
        case (is Artist, .playlist, false): String(localized: "Add or Remove Artist from Playlist")
        case (is Artist, .playlist, true): String(localized: "Remove Artist from Playlist")
        default: ""
        }
    }

    var body: some View {
        AsyncButton(computedTitle, systemSymbol: symbol) {
            let songs: [Song]

            switch media {
            case let album as Album:
                songs = try await album.getSongs()
            case let artist as Artist:
                let artistAlbums = try await artist.getAlbums()

                var artistSongs: [Song] = []
                for album in artistAlbums {
                    let albumSongs = try await album.getSongs()
                    artistSongs.append(contentsOf: albumSongs)
                }
                songs = artistSongs
            case let song as Song:
                songs = [song]
            default:
                throw ViewError.missingData
            }

            let existingSongs: [Song] = switch source {
            case .queue:
                mpd.queue.songs
            case .favorites:
                mpd.playlists.favorites
            case .playlist:
                try await ConnectionManager.command {
                    try await $0.getSongs(from: source)
                }
            default:
                throw ViewError.missingData
            }

            let existingFiles = Set(existingSongs.map(\.file))

            let shouldRemove = forceRemove || songs.contains(where: { existingFiles.contains($0.file) })

            if shouldRemove {
                try await ConnectionManager.command {
                    try await $0.remove(songs: songs, from: source)
                }
            } else {
                try await ConnectionManager.command {
                    try await $0.add(songs: songs, to: source)
                }
            }

            switch source {
            case .playlist, .favorites:
                NotificationCenter.default.post(name: .playlistModifiedNotification, object: nil)
            default:
                break
            }
        }
    }
}
