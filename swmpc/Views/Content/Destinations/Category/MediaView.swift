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
    private let sortDescriptor: SortDescriptor

    @State private var loadedSongs: [Song] = []
    @State private var sortedMedia: [any Mediable] = []

    private let playlistModifiedNotification = NotificationCenter.default
        .publisher(for: .playlistModifiedNotification)

    init(using database: DatabaseManager, searchQuery: String = "", sortDescriptor: SortDescriptor) {
        source = .database
        type = database.type
        self.searchQuery = searchQuery
        self.sortDescriptor = sortDescriptor
    }

    init(using _: QueueManager, searchQuery: String = "") {
        source = .queue
        type = .song
        self.searchQuery = searchQuery
        sortDescriptor = SortDescriptor(option: .title, direction: .ascending)
    }

    init(using playlist: Playlist, searchQuery: String = "") {
        source = playlist.name == "Favorites" ? .favorites : .playlist(playlist)
        type = .song
        self.searchQuery = searchQuery
        sortDescriptor = SortDescriptor(option: .title, direction: .ascending)
    }

    private var isMovable: Bool {
        switch source {
        case .queue, .playlist:
            true
        default:
            false
        }
    }

    private var baseMedia: [any Mediable] {
        switch source {
        case .queue:
            mpd.queue.songs
        case .playlist:
            loadedSongs
        case .favorites:
            mpd.playlists.favorites
        case .database:
            mpd.database.media ?? []
        }
    }

    var body: some View {
        Group {
            if sortedMedia.isEmpty {
                VStack {
                    Text("No content")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isMovable, let songs = sortedMedia as? [Song] {
                ForEach(songs) { song in
                    SongView(for: song, source: source)
                }
                .onMove { from, to in
                    Task {
                        guard let index = from.first,
                              index < sortedMedia.count,
                              let song = sortedMedia[index] as? Song
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
                    ForEach(sortedMedia.compactMap { $0 as? Album }) { album in
                        AlbumView(for: album)
                    }
                case .artist:
                    ForEach(sortedMedia.compactMap { $0 as? Artist }) { artist in
                        ArtistView(for: artist)
                    }
                case .song:
                    ForEach(sortedMedia.compactMap { $0 as? Song }) { song in
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
            .task(id: baseMedia.count) {
                sortedMedia = await SortingManager.sorted(
                    baseMedia,
                    by: sortDescriptor,
                    searchQuery: searchQuery,
                )
            }
            .task(id: searchQuery) {
                sortedMedia = await SortingManager.sorted(
                    baseMedia,
                    by: sortDescriptor,
                    searchQuery: searchQuery,
                )
            }
            .task(id: sortDescriptor) {
                sortedMedia = await SortingManager.sorted(
                    baseMedia,
                    by: sortDescriptor,
                    searchQuery: searchQuery,
                )
            }
    }
}
