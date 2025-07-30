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
    private let searchFields: Set<CategoryView.SearchField>

    @State private var loadedSongs: [Song] = []
    @State private var searchResults: [any Mediable] = []
    @State private var isSearching = false

    private let playlistModifiedNotification = NotificationCenter.default
        .publisher(for: .playlistModifiedNotification)

    init(using database: DatabaseManager, searchQuery: String = "", searchFields: Set<CategoryView.SearchField> = [.title, .artist, .album]) {
        source = .database
        type = database.type
        self.searchQuery = searchQuery
        self.searchFields = searchFields
    }

    init(using _: QueueManager, searchQuery: String = "", searchFields: Set<CategoryView.SearchField> = [.title, .artist, .album]) {
        source = .queue
        type = .song
        self.searchQuery = searchQuery
        self.searchFields = searchFields
    }

    init(using playlist: Playlist, searchQuery: String = "", searchFields: Set<CategoryView.SearchField> = [.title, .artist, .album]) {
        source = playlist.name == "Favorites" ? .favorites : .playlist(playlist)
        type = .song
        self.searchQuery = searchQuery
        self.searchFields = searchFields
    }

    private var media: [any Mediable] {
        // If searching, return search results
        if !searchQuery.isEmpty {
            return searchResults
        }
        
        // Otherwise return base media
        switch source {
        case .queue:
            return mpd.queue.songs
        case .playlist:
            return loadedSongs
        case .favorites:
            return mpd.playlists.favorites
        case .database:
            return mpd.database.media ?? []
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
            } else if source.isMovable, let songs = media as? [Song] {
                ForEach(songs) { song in
                    SongView(for: song, source: source)
                }
                .onMove(perform: move)
            } else {
                // Non-movable media
                ForEach(media, id: \.id) { item in
                    switch item {
                    case let album as Album:
                        AlbumView(for: album)
                    case let artist as Artist:
                        ArtistView(for: artist)
                    case let song as Song:
                        SongView(for: song, source: source)
                    default:
                        EmptyView()
                    }
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
//                Task {
//                    await refreshPlaylistSongs()
//                }
            }
            .task {
                await loadPlaylistSongs()
            }
            .onChange(of: searchQuery) { _, newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
    }
    
    private func performSearch(query: String) async {
        guard !query.isEmpty, source == .database else {
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        // Convert SearchField to MPD field names
        let mpdFields = searchFields.compactMap { field -> String in
            switch field {
            case .title: return "title"
            case .artist: return "artist"
            case .album: return "album"
            }
        }
        
        do {
            switch type {
            case .song:
                let results = try await ConnectionManager.command().search(
                    query: query,
                    fields: Set(mpdFields),
                    returning: Song.self
                )
                searchResults = results
            case .album:
                let results = try await ConnectionManager.command().search(
                    query: query,
                    fields: Set(mpdFields),
                    returning: Album.self
                )
                searchResults = results
            case .artist:
                let results = try await ConnectionManager.command().search(
                    query: query,
                    fields: Set(mpdFields),
                    returning: Artist.self
                )
                searchResults = results
            case .playlist:
                searchResults = []
            }
        } catch {
            searchResults = []
        }
        
        isSearching = false
    }

    private func move(from source: IndexSet, to destination: Int) {
        Task {
            guard let index = source.first,
                  index >= 0,
                  index < media.count,
                  destination >= 0,
                  destination <= media.count,
                  let song = media[index] as? Song,
                  searchQuery.isEmpty // Prevent moves during search
            else {
                return
            }

            let adjustedTo = index < destination ? destination - 1 : destination
            try? await ConnectionManager.command().move(song, to: adjustedTo, in: self.source)

            if case .playlist = self.source {
                NotificationCenter.default.post(name: .playlistModifiedNotification, object: nil)
            } else if case .favorites = self.source {
                NotificationCenter.default.post(name: .playlistModifiedNotification, object: nil)
            }
        }
    }

    private func loadPlaylistSongs() async {
        guard loadedSongs.isEmpty,
              case let .playlist(playlist) = source
        else {
            return
        }

        loadedSongs = await (try? mpd.playlists.getSongs(for: playlist)) ?? []
    }

    private func refreshPlaylistSongs() async {
        if case let .playlist(playlist) = source {
            if playlist.name == "Favorites" {
                try? await mpd.playlists.set()
            } else {
                loadedSongs = await (try? mpd.playlists.getSongs(for: playlist)) ?? []
            }
        }
    }
}
