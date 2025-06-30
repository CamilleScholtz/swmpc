//
//  RowContextMenuView.swift
//  swmpc
//
//  Created by Camille Scholtz on 30/06/2025.
//

import ButtonKit
import SwiftUI

enum SourceToggleButtonAction {
    case add
    case remove
}

enum MembershipContext: Equatable {
    case none
    case queued
    case favorited
    case inPlaylist(Playlist)

    var isMovable: Bool {
        switch self {
        case .queued, .inPlaylist:
            true
        case .none, .favorited:
            false
        }
    }

    var showsHandle: Bool {
        isMovable
    }

    var contextMenuAction: SourceToggleButtonAction? {
        switch self {
        case .none:
            nil
        case .queued, .favorited, .inPlaylist:
            .remove
        }
    }
}

struct RowContextMenuView<Media: Mediable>: View {
    @Environment(MPD.self) private var mpd

    @AppStorage(Setting.simpleMode) private var simpleMode = false

    let media: Media
    let membershipContext: MembershipContext

    init(for media: Media, membershipContext: MembershipContext = .none) {
        self.media = media
        self.membershipContext = membershipContext
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
        default: "Item"
        }

        return "Add or Remove \(mediaType) from Playlist"
    }

    var body: some View {
        if !simpleMode {
            SourceToggleButton(media: media, source: .queue, action: membershipContext == .queued ? .remove : nil)
            Divider()
        }

        Button(copyTitle) {
            textToCopy.copyToClipboard()
        }

        Divider()

        SourceToggleButton(media: media, source: .favorites, action: membershipContext == .favorited ? .remove : nil)

        if let playlists = (mpd.status.playlist != nil) ? mpd.playlists.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.playlists.playlists {
            Menu(playlistMenuTitle) {
                ForEach(playlists) { playlist in
                    let action: SourceToggleButtonAction? = if case let .inPlaylist(contextPlaylist) = membershipContext, contextPlaylist == playlist {
                        .remove
                    } else {
                        nil
                    }
                    SourceToggleButton(media: media, source: .playlist(playlist), action: action)
                }
            }
        }
    }
}

struct SourceToggleButton<Media: Mediable>: View {
    @Environment(MPD.self) private var mpd

    let media: Media
    let source: Source
    var action: SourceToggleButtonAction? = nil

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
        switch action {
        case .add: "Add"
        case .remove: "Remove"
        default: "Add or Remove"
        }
    }

    private var title: String {
        switch source {
        case .playlist: String(localized: sourceName)
        default: String(localized: "\(String(localized: actionName)) \(String(localized: mediaTypeName)) from \(String(localized: sourceName))")
        }
    }

    var body: some View {
        AsyncButton(title) {
            let songs: [Song]
            switch media {
            case let album as Album:
                songs = try await ConnectionManager.command().getSongs(in: album, from: .database)
            case let artist as Artist:
                songs = try await ConnectionManager.command().getSongs(by: artist, from: .database)
            case let song as Song:
                songs = [song]
            default:
                throw ViewError.missingData
            }

            let urls: Set<URL>
            switch source {
            case .queue:
                urls = Set(mpd.queue.internalMedia.map(\.url))
            case .favorites:
                urls = Set(mpd.playlists.favorites.map(\.url))
            case .playlist:
                let playlistSongs = try await ConnectionManager.command().getSongs(from: source)
                urls = Set(playlistSongs.map(\.url))
            default:
                throw ViewError.missingData
            }

            if songs.contains(where: { urls.contains($0.url) }) {
                do {
                    try await ConnectionManager.command().remove(songs: songs, from: source)
                } catch {
                    print(error)
                }
            } else {
                try await ConnectionManager.command().add(songs: songs, to: source)
            }
        }
    }
}
