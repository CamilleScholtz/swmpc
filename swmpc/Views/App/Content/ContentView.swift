//
//  ContentView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import NavigatorUI
import SwiftUI

extension SidebarDestination: NavigationDestination {
    var body: some View {
        SidebarDestinationViewBuilder(destination: self)
    }

    private struct SidebarDestinationViewBuilder: View {
        @Environment(MPD.self) private var mpd

        let destination: SidebarDestination

        var body: some View {
            if mpd.queue.internalMedia.isEmpty {
                EmptyContentView(destination: destination)
            } else {
                ContentView(destination: destination)
            }
        }
    }

    private struct ContentView: View {
        @Environment(MPD.self) private var mpd

        let destination: SidebarDestination

        @State private var isSearching = false

        private let scrollToCurrentNotification = NotificationCenter.default
            .publisher(for: .scrollToCurrentNotification)
        private let startSearchingNotication = NotificationCenter.default
            .publisher(for: .startSearchingNotication)

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    HeaderView(destination: .constant(destination), isSearching: $isSearching)
                        .id("top")

                    LazyVStack(alignment: .leading, spacing: 15) {
                        switch destination {
                        case .albums:
                            AlbumsView()
                        case .artists:
                            ArtistsView()
                        case .songs, .playlist:
                            SongsView()
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 15)
                }
                .onAppear {
                    // TODO: For some reason this fires twice.
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
                    proxy.scrollTo(media, anchor: .center)
                }
            } else {
                proxy.scrollTo(media, anchor: .center)
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

    private struct EmptyContentView: View {
        @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabled = false

        let destination: SidebarDestination

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

                    IntelligenceButtonView("Create Playlist using AI")
                        .offset(y: 20)
                        .onTapGesture {
                            guard isIntelligenceEnabled else {
                                return
                            }

                            NotificationCenter.default.post(name: .createIntelligencePlaylistNotification, object: playlist)
                        }
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
}

extension ContentDestination: NavigationDestination {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                BackButtonView()
                    .offset(y: 5)

                switch self {
                case let .album(album):
                    AlbumSongsView(for: album)
                case let .artist(artist):
                    ArtistAlbumsView(for: artist)
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 15)
        }
        .ignoresSafeArea()
    }
}
