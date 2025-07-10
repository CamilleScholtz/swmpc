//
//  MediaView.swift
//  swmpc
//
//  Created by Camille Scholtz on 21/06/2025.
//

import SwiftUI

struct MediaView: View {
    @Environment(MPD.self) private var mpd

    let source: Source?
    let type: MediaType
    let searchQuery: String

    @State private var playlistSongs: [Song] = []
    @State private var hasFetchedDatabaseSongs = false

    private let startSearchingNotification = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    private let playlistModifiedNotification = NotificationCenter.default
        .publisher(for: .playlistModifiedNotification)

    init(using _: DatabaseManager, type: MediaType, searchQuery: String = "") {
        source = nil
        self.type = type
        self.searchQuery = searchQuery
    }

    init(using _: QueueManager, searchQuery: String = "") {
        source = .queue
        type = .song
        self.searchQuery = searchQuery
    }

    // Playlist initializer
    init(for playlist: Playlist, searchQuery: String = "") {
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
        switch source {
        case .queue:
            return mpd.queue.songs
        case .playlist:
            if searchQuery.isEmpty {
                return playlistSongs
            } else {
                return playlistSongs.filter {
                    $0.artist.range(of: searchQuery, options: .caseInsensitive) != nil ||
                        $0.title.range(of: searchQuery, options: .caseInsensitive) != nil
                }
            }
        case .favorites:
            return mpd.playlists.favorites
        default:
            switch type {
            case .artist:
                guard let albums = mpd.database.albums else {
                    return []
                }
                
                let artistDict = Dictionary(grouping: albums.compactMap(\.artist), by: { $0.name })
                let artists = artistDict.values.compactMap(\.first).sorted { $0.name < $1.name }
                
                if searchQuery.isEmpty {
                    return artists
                } else {
                    return artists.filter {
                        $0.name.range(of: searchQuery, options: .caseInsensitive) != nil
                    }
                }
            case .album:
                guard let albums = mpd.database.albums else {
                    return []
                }
                
                if searchQuery.isEmpty {
                    return albums
                } else {
                    return albums.filter {
                        $0.title.range(of: searchQuery, options: .caseInsensitive) != nil ||
                        ($0.artist.name.range(of: searchQuery, options: .caseInsensitive) != nil)
                    }
                }
            default:
               // TODO
                return []
            }
        }
    }

    var body: some View {
        Group {
            switch type {
            case .song:
                let songs = media.compactMap { $0 as? Song }
                if isMovable {
                    ForEach(songs) { song in
                        SongView(for: song, source: source)
                    }
                    .onMove { from, to in
                        Task {
                            guard let index = from.first,
                                  index < songs.count,
                                  let source
                            else {
                                return
                            }

                            let song = songs[index]
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
                    ForEach(songs) { song in
                        SongView(for: song, source: source)
                    }
                }
            case .album:
                ForEach(media.compactMap { $0 as? Album }) { album in
                    AlbumView(for: album)
                }
            case .artist:
                ForEach(media.compactMap { $0 as? Artist }) { artist in
                    ArtistView(for: artist)
                }
            default:
                EmptyView()
            }
        }
        .listRowSeparator(.hidden)
        #if os(iOS)
            .listRowInsets(.init(top: 7.5, leading: 15, bottom: 7.5, trailing: 15))
        #elseif os(macOS)
            .listRowInsets(.init(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5))
        #endif
            .onReceive(startSearchingNotification) { notification in
                // Search query is now managed by the parent view and passed as a parameter
            }
            .onReceive(playlistModifiedNotification) { _ in
                Task {
                    if case let .playlist(playlist) = source {
                        if playlist.name == "Favorites" {
                            try? await mpd.playlists.set()
                        } else {
                            try? await mpd.playlists.refreshPlaylist(playlist)
                            playlistSongs = mpd.playlists.songs(for: playlist)
                        }
                    }
                }
            }
//            .task {
//                // Fetch database songs only when needed
//                if source == nil && type == .song && !hasFetchedDatabaseSongs {
//                    do {
//                        try await mpd.database.fetchSongs()
//                        hasFetchedDatabaseSongs = true
//                    } catch {
//                        // Handle error silently or log if needed
//                    }
//                }
//            }
    }
}
