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
                if mpd.queue.internalMedia.isEmpty {
                    EmptyCategoryView(destination: destination)
                } else {
                    CategoryView(destination: destination)
                }
            }
        #elseif os(macOS)
            if mpd.queue.internalMedia.isEmpty {
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

    @State private var isSearching = false

    private let scrollToCurrentNotification = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)
    private let startSearchingNotication = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                #if os(macOS)
                    HeaderView(destination: destination, isSearching: $isSearching)
                        .id("top")
                #endif

                LazyVStack(alignment: .leading, spacing: 15) {
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
                .id(destination)
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
            }
            .onAppear {
                guard mpd.status.media != nil else {
                    return
                }

                scrollToCurrent(proxy, animate: false)
            }
            .onReceive(scrollToCurrentNotification) { notification in
                scrollToCurrent(proxy, animate: notification.object as? Bool ?? true)
            }
            .onReceive(startSearchingNotication) { _ in
                scrollToTop(proxy)

                isSearching = true
            }
        }
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

    private func scrollToTop(_ proxy: ScrollViewProxy, animate: Bool = true) {
        if animate {
            withAnimation {
                proxy.scrollTo("top", anchor: .center)
            }
        } else {
            proxy.scrollTo("top", anchor: .center)
        }
    }
}
