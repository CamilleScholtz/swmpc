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
        let mediaType = switch media {
        case is Song: String(localized: "Song")
        case is Album: String(localized: "Album")
        case is Artist: String(localized: "Artist")
        default: ""
        }

        return String(localized: "Add or Remove \(mediaType) from Playlist")
    }

    var body: some View {
        if source != .database {
            SourceToggleButton(media: media, source: source, forceAction: .remove)
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
    var forceAction: SourceToggleButtonAction?
    var title: String?

    enum SourceToggleButtonAction {
        case add
        case remove
    }

    private var mediaTypeName: LocalizedStringResource {
        switch media {
        case is Album: "Album"
        case is Artist: "Artist"
        case is Song: "Song"
        default: LocalizedStringResource(stringLiteral: "")
        }
    }

    private var sourceName: LocalizedStringResource {
        switch source {
        case .queue: "Queue"
        case .favorites: "Favorites"
        case let .playlist(playlist): LocalizedStringResource(stringLiteral: playlist.name)
        default: LocalizedStringResource(stringLiteral: "")
        }
    }

    private var action: LocalizedStringResource {
        if let forceAction {
            switch forceAction {
            case .add: "Add"
            case .remove: "Remove"
            }
        } else {
            "Add or Remove"
        }
    }

    private var symbol: SFSymbol {
        switch source {
        case .queue:
            if let forceAction {
                switch forceAction {
                case .add: .plusCircle
                case .remove: .minusCircle
                }
            } else {
                .musicNoteList
            }
        case .favorites:
            .heart
        case .playlist:
            .musicNoteList
        default:
            .plusCircle
        }
    }

    private var computedTitle: String {
        guard title == nil else {
            return title!
        }

        return switch source {
        case .playlist:
            String(localized: "\(String(localized: action)) \(String(localized: mediaTypeName)) from Playlist")
        default:
            String(localized: "\(String(localized: action)) \(String(localized: mediaTypeName)) from \(String(localized: sourceName))")
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

            let shouldRemove: Bool = if let forceAction {
                forceAction == .remove
            } else {
                songs.contains(where: { existingFiles.contains($0.file) })
            }

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
