//
//  MediaView.swift
//  swmpc
//
//  Created by Camille Scholtz on 21/06/2025.
//

import SwiftUI

struct MediaView: View {
    @Environment(MPD.self) private var mpd

    private let source: Source
    private let type: MediaType
    private let searchQuery: String

    @State private var loadedSongs: [Song] = []

    private let playlistModifiedNotification = NotificationCenter.default
        .publisher(for: .playlistModifiedNotification)

    init(using database: DatabaseManager, searchQuery: String = "") {
        source = .database
        type = database.type
        self.searchQuery = searchQuery
    }

    init(using _: QueueManager, searchQuery: String = "") {
        source = .queue
        type = .song
        self.searchQuery = searchQuery
    }

    init(using playlist: Playlist, searchQuery: String = "") {
        source = playlist.name == "Favorites" ? .favorites : .playlist(playlist)
        type = .song
        self.searchQuery = searchQuery
    }

    private var isMovable: Bool {
        switch source {
        case .queue, .playlist:
            true
        default:
            false
        }
    }

    private var media: [any Mediable] {
        let baseMedia: [any Mediable] = switch source {
        case .queue:
            mpd.queue.songs
        case .playlist:
            loadedSongs
        case .favorites:
            mpd.playlists.favorites
        case .database:
            mpd.database.media ?? []
        }

        guard !searchQuery.isEmpty else {
            return baseMedia
        }

        return baseMedia.filter { mediable in
            switch mediable {
            case let song as Song:
                song.artist.range(of: searchQuery, options: .caseInsensitive) != nil ||
                    song.title.range(of: searchQuery, options: .caseInsensitive) != nil
            case let album as Album:
                album.title.range(of: searchQuery, options: .caseInsensitive) != nil ||
                    album.artist.name.range(of: searchQuery, options: .caseInsensitive) != nil
            case let artist as Artist:
                artist.name.range(of: searchQuery, options: .caseInsensitive) != nil
            default:
                false
            }
        }
    }

    var body: some View {
        Group {
            if media.isEmpty {
                VStack {
                    Text("No content")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isMovable, let songs = media as? [Song] {
                ForEach(songs) { song in
                    SongView(for: song, source: source)
                }
                .onMove { from, to in
                    Task {
                        guard let index = from.first,
                              index < media.count,
                              let song = media[index] as? Song
                        else {
                            return
                        }

                        let adjustedTo = index < to ? to - 1 : to
                        try? await ConnectionManager.command().move(song, to: adjustedTo, in: source)

                        if case .playlist = source {
                            NotificationCenter.default.post(name: .playlistModifiedNotification, object: nil)
                        } else if case .favorites = source {
                            NotificationCenter.default.post(name: .playlistModifiedNotification, object: nil)
                        }
                    }
                }
            } else {
                switch type {
                case .album:
                    ForEach(media.compactMap { $0 as? Album }) { album in
                        AlbumView(for: album)
                    }
                case .artist:
                    ForEach(media.compactMap { $0 as? Artist }) { artist in
                        ArtistView(for: artist)
                    }
                case .song:
                    ForEach(media.compactMap { $0 as? Song }) { song in
                        SongView(for: song, source: source)
                    }
                default:
                    EmptyView()
                }
            }
        }
        .listRowSeparator(.hidden)
        #if os(iOS)
            .listRowInsets(.init(top: 7.5, leading: 15, bottom: 7.5, trailing: 15))
        #elseif os(macOS)
            .listRowInsets(.init(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5))
        #endif
            .onReceive(playlistModifiedNotification) { _ in
                Task {
                    if case let .playlist(playlist) = source {
                        if playlist.name == "Favorites" {
                            try? await mpd.playlists.set()
                        } else {
                            loadedSongs = await (try? mpd.playlists.getSongs(for: playlist)) ?? []
                        }
                    }
                }
            }
            .task {
                guard loadedSongs.isEmpty else {
                    return
                }

                if case let .playlist(playlist) = source {
                    loadedSongs = await (try? mpd.playlists.getSongs(for: playlist)) ?? []
                }
            }
    }
}
