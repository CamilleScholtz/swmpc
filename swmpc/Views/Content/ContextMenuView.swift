//
//  ContextMenuView.swift
//  swmpc
//
//  Created by Camille Scholtz on 30/06/2025.
//

import ButtonKit
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
            "Copy Song Title"
        case is Album:
            "Copy Album Title"
        case is Artist:
            "Copy Artist Name"
        default:
            "Copy Title"
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
        case is Song: "Song"
        case is Album: "Album"
        case is Artist: "Artist"
        default: ""
        }

        return "Add or Remove \(mediaType) from Playlist"
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

        if let playlists = (mpd.status.playlist != nil) ? mpd.playlists.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.playlists.playlists {
            Menu(playlistMenuTitle) {
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

        Button(copyTitle) {
            textToCopy.copyToClipboard()
        }
    }
}

struct SourceToggleButton<Media: Mediable>: View {
    @Environment(MPD.self) private var mpd

    let media: Media
    let source: Source
    var forceAction: SourceToggleButtonAction? = nil
    var title: String? = nil

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

    private var actionName: LocalizedStringResource {
        if let forceAction {
            switch forceAction {
            case .add: "Add"
            case .remove: "Remove"
            }
        } else {
            "Add or Remove"
        }
    }

    private var computedTitle: String {
        guard title == nil else {
            return title!
        }

        return switch source {
        case .playlist:
            String(localized: "\(String(localized: actionName)) \(String(localized: mediaTypeName)) from Playlist")
        default:
            String(localized: "\(String(localized: actionName)) \(String(localized: mediaTypeName)) from \(String(localized: sourceName))")
        }
    }

    var body: some View {
        AsyncButton(computedTitle) {
            let songs: [Song]

            switch media {
            case let album as Album:
                songs = try await album.getSongs()
            case let artist as Artist:
                let allAlbums = try await ConnectionManager.command().getDatabase() ?? []
                let artistAlbums = allAlbums.filter { $0.artist.name == artist.name }

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

            let urls: Set<URL>
            switch source {
            case .queue:
                urls = Set(mpd.queue.songs.map(\.url))
            case .favorites:
                urls = Set(mpd.playlists.favorites.map(\.url))
            case .playlist:
                let playlistSongs = try await ConnectionManager.command().getSongs(from: source)
                urls = Set(playlistSongs.map(\.url))
            default:
                throw ViewError.missingData
            }

            let shouldRemove: Bool = if let forceAction {
                // If action is forced, use it regardless of current state
                forceAction == .remove
            } else {
                // If not forced, toggle based on current presence
                songs.contains(where: { urls.contains($0.url) })
            }

            if shouldRemove {
                try await ConnectionManager.command().remove(songs: songs, from: source)
            } else {
                try await ConnectionManager.command().add(songs: songs, to: source)
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
