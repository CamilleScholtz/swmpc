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

    var body: some View {
        #if os(iOS)
            switch destination {
            case .playlists:
                PlaylistsView()
            case .settings:
                SettingsView()
            default:
                if mpd.database.internalMedia.isEmpty {
                    EmptyCategoryView(destination: destination)
                } else {
                    CategoryView(destination: destination)
                }
            }
        #elseif os(macOS)
            if mpd.database.internalMedia.isEmpty {
                EmptyCategoryView(destination: destination)
            } else {
                CategoryView(destination: destination)
            }
        #endif
    }
}

struct EmptyCategoryView: View {
    @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabled = false

    let destination: CategoryDestination

    @State private var showIntelligencePlaylistSheet = false
    @State private var playlistToEdit: Playlist?
    @State private var intelligencePlaylistPrompt = ""

    private let createIntelligencePlaylistNotification = NotificationCenter.default
        .publisher(for: .createIntelligencePlaylistNotification)

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
        .onReceive(createIntelligencePlaylistNotification) { notification in
            guard let playlist = notification.object as? Playlist else {
                return
            }

            playlistToEdit = playlist
            showIntelligencePlaylistSheet = true
        }
        .sheet(isPresented: $showIntelligencePlaylistSheet) {
            IntelligencePlaylistView(showIntelligencePlaylistSheet: $showIntelligencePlaylistSheet, playlistToEdit: $playlistToEdit)
        }
    }
}

struct CategoryView: View {
    @Environment(MPD.self) private var mpd

    let destination: CategoryDestination

    @State private var offset: CGFloat = 0

    @State private var showHeader = false
    @State private var isSearching = false

    @State private var hideHeaderTask: Task<Void, Never>?

    @State private var showSearchButton = false
    @State private var isGoingToSearch = false
    @State private var query = ""

    @State private var scrollPosition: URL?

    private let scrollToCurrentNotification = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)
    private let startSearchingNotication = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 15) {
                switch destination {
                case .albums:
                    AlbumsView()
                case .artists:
                    ArtistsView()
                case .songs, .playlist:
                    SongsView()
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
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .onAppear {
            guard let media = mpd.status.media else {
                return
            }

            scrollPosition = media.id
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
        .onChange(of: showHeader) { _, value in
            if value {
                resetHideHeaderTimer()
            } else {
                hideHeaderTask?.cancel()
            }
        }
        .onChange(of: isSearching) { _, value in
            if value {
                showHeader = true
                hideHeaderTask?.cancel()
            } else {
                resetHideHeaderTimer()
            }
        }
        .onChange(of: mpd.database.results?.count) { _, value in
            guard value == nil, let media = mpd.status.media else {
                return
            }

            scrollPosition = media.id
        }
//            .navigationTitle(destination.label)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
//            .toolbar {
//                ToolbarItem() {
//                    Button {
//                        if isSearching {
//                            isSearching = false
//                        } else {
//                            isGoingToSearch = true
//                        }
//                    } label: {
//                        Image(systemSymbol: .magnifyingglass)
//                            .padding(5)
//                    }
//                }
//            }
        .searchable(text: $query, isPresented: $isSearching, placement: .toolbar)
        .disableAutocorrection(true)
        .onChange(of: isSearching) { _, value in
            guard !value else {
                return
            }

            mpd.database.results = nil
        }
        .onChange(of: isGoingToSearch) { _, value in
            guard value else {
                return
            }

            isSearching = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isGoingToSearch = false
            }
            
//            if query.isEmpty {
//                mpd.database.results = nil
//            } else {
//                Task {
//                    //                let playlist: Playlist? = switch navigator.category {
//                    //                case let .playlist(playlist): playlist
//                    //                default: nil
//                    //                }
//                    let playlist = nil
//                    try? await mpd.database.search(for: query, playlist: playlist)
//                }
//            }
        }
        .task(id: query) {
            guard isSearching else {
                return
            }

            if query.isEmpty {
                mpd.database.results = nil
            } else {
                try? await mpd.database.search(for: query)
            }
        }
        .animation(.spring, value: showHeader)
    }

    private func resetHideHeaderTimer(offset: CGFloat) {
        hideHeaderTask?.cancel()
        guard showHeader, !isSearching, offset > 0 else {
            return
        }

        hideHeaderTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, showHeader, !isSearching, offset > 0 else {
                return
            }

            showHeader = false
        }
    }

    private func resetHideHeaderTimer() {
        resetHideHeaderTimer(offset: offset)
    }
}
