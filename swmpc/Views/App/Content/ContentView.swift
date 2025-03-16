//
//  ContentView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import Navigator
import SFSafeSymbols
import SwiftUI

struct ContentView: View {
    @Environment(MPD.self) private var mpd

    var body: some View {
        if mpd.queue.media.isEmpty {
            EmptyContentView()
                .ignoresSafeArea()
        } else {
            ManagedNavigationStack(scene: "content") {
                SidebarDestination.albums
                    .navigationDestination(SidebarDestination.self)
                    .ignoresSafeArea()
            }
        }
    }

    struct EmptyContentView: View {
        @Environment(Router.self) private var router

        @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabled = false

        @State private var showIntelligencePlaylistSheet = false
        @State private var playlistToEdit: Playlist?
        @State private var intelligencePlaylistPrompt = ""

        private let createIntelligencePlaylistNotification = NotificationCenter.default
            .publisher(for: .createIntelligencePlaylistNotification)

        var body: some View {
            VStack {
                switch router.category.type {
                case .playlist:
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

                            NotificationCenter.default.post(name: .createIntelligencePlaylistNotification, object: router.category.playlist)
                        }
                default:
                    Text("No \(router.category.label.lowercased()) in library.")
                        .font(.headline)

                    Text("Add songs to your library.")
                        .font(.subheadline)
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

    struct FilledContentView: View {
        @Environment(MPD.self) private var mpd
        @Environment(Router.self) private var router

        @State private var isHovering = false
        @State private var isSearching = false

        private let scrollToCurrentNotification = NotificationCenter.default
            .publisher(for: .scrollToCurrentNotification)
        private let startSearchingNotication = NotificationCenter.default
            .publisher(for: .startSearchingNotication)

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView {
//                    HeaderView(isSearching: $isSearching)
//                        .id("top")

                    LazyVStack(alignment: .leading, spacing: 15) {
                        switch router.category.type {
                        case .artist:
                            ArtistsView()
                        case .song, .playlist:
                            SongsView()
                        default:
                            AlbumsView()
                        }
                    }
                    .id(router.category)
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
}

struct ArtworkView: View {
    @Binding var image: NSImage?

    var body: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaledToFit()
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
        } else {
            Rectangle()
                .fill(Color(.secondarySystemFill).opacity(0.3))
                .aspectRatio(contentMode: .fit)
                .scaledToFill()
        }
    }
}
