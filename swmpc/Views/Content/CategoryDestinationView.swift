//
//  CategoryDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct CategoryDestinationView: View {
    @Environment(MPD.self) private var mpd

    let destination: CategoryDestination

    @State private var isLoadingPlaylist = true
    @State private var playlistSongs: [Song]?

    var body: some View {
        switch destination {
        #if os(iOS)
            case .playlists:
                PlaylistsView()
            case .settings:
                SettingsView()
        #endif
        case let .playlist(playlist):
            Group {
                if isLoadingPlaylist {
                    ZStack {
                        Rectangle()
                            .fill(.background)
                            .ignoresSafeArea()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        ProgressView()
                    }
                } else if playlistSongs == nil || playlistSongs!.isEmpty {
                    EmptyCategoryView(destination: destination)
                } else {
                    CategoryView(destination: destination)
                }
            }
            .task(id: playlist) {
                isLoadingPlaylist = true
                playlistSongs = try? await ConnectionManager.command().getSongs(for: playlist)

                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else {
                    return
                }

                isLoadingPlaylist = false
            }
        default:
            if mpd.database.internalMedia.isEmpty {
                EmptyCategoryView(destination: destination)
            } else {
                CategoryView(destination: destination)
            }
        }
    }
}

struct EmptyCategoryView: View {
    @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabled = false

    let destination: CategoryDestination

    @State private var showIntelligencePlaylistSheet = false
    @State private var playlistToEdit: Playlist?
    @State private var intelligencePlaylistPrompt = ""

    private let fillIntelligencePlaylistNotification = NotificationCenter.default
        .publisher(for: .fillIntelligencePlaylistNotification)

    var body: some View {
        VStack {
            switch destination {
            case .albums, .artists, .songs:
                Text("No \(destination.label.lowercased()) in library.")
                    .font(.headline)

                Text("Add songs to your library.")
                    .font(.subheadline)
            case let .playlist(playlist):
                Text("No songs in playlist.")
                    .font(.headline)
                Text("Add songs to your playlist.")
                    .font(.subheadline)

                IntelligenceButtonView(using: playlist)
                    .offset(y: 20)
            #if os(iOS)
                default:
                    EmptyView()
            #endif
            }
        }
        .offset(y: -20)
        .onReceive(fillIntelligencePlaylistNotification) { notification in
            guard let playlist = notification.object as? Playlist else {
                return
            }

            playlistToEdit = playlist
            showIntelligencePlaylistSheet = true
        }
        .sheet(isPresented: $showIntelligencePlaylistSheet) {
            IntelligenceView(target: .playlist($playlistToEdit), showSheet: $showIntelligencePlaylistSheet)
        }
    }
}

struct CategoryView: View {
    @Environment(MPD.self) private var mpd

    let destination: CategoryDestination

    @State private var offset: CGFloat = 0

    @State private var isSearching = false

    @State private var scrollPosition: URL?

    @State private var showSearchButton = false
    @State private var isGoingToSearch = false
    @State private var query = ""

    private let scrollToCurrentNotification = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)
    private let startSearchingNotication = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                switch destination {
                case .albums:
                    MediaListView(using: mpd.database, type: .album)
                case .artists:
                    MediaListView(using: mpd.database, type: .artist)
                case .songs:
                    MediaListView(using: mpd.database, type: .song)
                case let .playlist(playlist):
                    MediaListView(for: playlist)
                #if os(iOS)
                    default:
                        EmptyView()
                #endif
                }
            }
            .scrollTargetLayout()
        }
        .id(destination)
        .contentMargins(.all, 15, for: .scrollContent)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .task(id: destination) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.database.get(for: song, using: destination.type)
            scrollToCurrent(proxy, animate: false)
        }
        .task(id: mpd.status.song, priority: .medium) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.database.get(for: song, using: destination.type)
            scrollToCurrent(proxy, animate: false)
        }
        .onReceive(scrollToCurrentNotification) { notification in
            guard let media = mpd.status.media else {
                return
            }

            let animate = notification.object as? Bool ?? true
            if animate {
                withAnimation(.spring) {
                    scrollPosition = media.id
                }
            } else {
                scrollPosition = media.id
            }
        }
        .onReceive(startSearchingNotication) { _ in
            isSearching = true
        }
        .onChange(of: mpd.database.results?.count) { _, value in
            guard value == nil, let media = mpd.status.media else {
                return
            }

            scrollPosition = media.id
        }
        .navigationTitle(destination.label)
//        .searchable(text: $query, isPresented: $isSearching)
//        .scrollEdgeEffectStyle(.soft, for: .top)
//        .scrollEdgeEffectDisabled(false)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if isSearching {
                            isSearching = false
                        } else {
                            isGoingToSearch = true
                        }
                    } label: {
                        Image(systemSymbol: .magnifyingglass)
                            .padding(5)
                    }
                    .opacity(showSearchButton ? 1 : 0)
                    .animation(.spring, value: showSearchButton)
                }
            }
            .searchable(text: $query, isPresented: $isSearching)
            .onChange(of: isSearching) { _, value in
                guard !value else {
                    return
                }

                mpd.database.results = nil
                // For playlists, notify to clear search results
                if case .playlist = navigator.category {
                    NotificationCenter.default.post(name: .startSearchingNotication, object: "")
                }
            }
            .onChange(of: isGoingToSearch) { _, value in
                guard value else {
                    return
                }

                isSearching = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isGoingToSearch = false
                }
            }
            .task(id: query) {
                guard isSearching else {
                    return
                }

                if query.isEmpty {
                    mpd.database.results = nil
                    // For playlists, notify to clear search results
                    if case .playlist = navigator.category {
                        NotificationCenter.default.post(name: .startSearchingNotication, object: "")
                    }
                } else {
                    // For playlists, search is handled by MediaListView internally
                    if case .playlist = navigator.category {
                        NotificationCenter.default.post(name: .startSearchingNotication, object: query)
                    } else {
                        try? await mpd.database.search(for: query)
                    }
                }
            }
        #endif
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy, animate: Bool = true) {
        guard let media = mpd.status.media else {
            return
        }

        if animate {
            withAnimation {
                proxy.scrollTo(media.id, anchor: .center)
            }
        } else {
            proxy.scrollTo(media.id, anchor: .center)
        }
    }
}
