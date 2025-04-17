//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

#if os(iOS)
    import LNPopupUI
#endif

enum ViewError: Error {
    case missingData
}

struct AppView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    @State private var initialFetch = true
    @State private var artwork: PlatformImage?

    #if os(iOS)
        @State private var songs: [Int: [Song]]?

        @State private var isPopupBarPresented = true
        @State private var isPopupOpen = false
    #endif

    var body: some View {
        Group {
            if mpd.status.state == nil {
                ErrorView()
            } else {
                Group {
                    @Bindable var boundNavigator = navigator

                    #if os(iOS)
                        TabView(selection: $boundNavigator.category) {
                            ForEach(CategoryDestination.categories) { category in
                                // NOTE: Use SFSafeSymbols version when it is available.
                                // https://github.com/SFSafeSymbols/SFSafeSymbols/issues/138
                                Tab(category.label, systemImage: category.symbol.rawValue, value: category) {
                                    ZStack {
                                        NavigationStack(path: $boundNavigator.path) {
                                            CategoryDestinationView(destination: category)
                                                .navigationDestination(for: ContentDestination.self) { destination in
                                                    ContentDestinationView(destination: destination)
                                                }
                                        }

                                        LoadingView()
                                    }
                                }
                            }
                        }
                        .handleQueueChange()
                        .popup(isBarPresented: $isPopupBarPresented, isPopupOpen: $isPopupOpen) {
                            ScrollView {
                                VStack(spacing: 50) {
                                    DetailView(artwork: artwork, isPopupOpen: $isPopupOpen)
                                        .frame(height: 550)

                                    if let songs {
                                        ForEach(songs.keys.sorted(), id: \.self) { disc in
                                            VStack(alignment: .leading, spacing: 15) {
                                                if songs.keys.count > 1 {
                                                    Text("Disc \(String(disc))")
                                                        .font(.headline)
                                                        .padding(.top, disc == songs.keys.sorted().first ? 0 : 10)
                                                }

                                                ForEach(songs[disc] ?? []) { song in
                                                    SongView(for: song)
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 30)
                            }
                        }
                        .popupBarProgressViewStyle(.top)
                    #elseif os(macOS)
                        NavigationSplitView {
                            SidebarView()
                                .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: .infinity)
                        } content: {
                            NavigationStack(path: $boundNavigator.path) {
                                CategoryDestinationView(destination: navigator.category)
                                    .navigationDestination(for: ContentDestination.self) { destination in
                                        ContentDestinationView(destination: destination)
                                    }
                            }
                            .navigationSplitViewColumnWidth(310)
                            .navigationBarBackButtonHidden(true)
                            .ignoresSafeArea()
                            .overlay(
                                LoadingView()
                            )
                        } detail: {
                            DetailView(artwork: artwork)
                                .padding(60)
                        }
                        .background(.background)
                    #endif
                }
                .task(id: mpd.status.song) {
                    guard let song = mpd.status.song else {
                        artwork = nil
                        return
                    }

                    // NOTE: Hack, without this getting the initial artwork
                    // fails when not on localhost connections. I suspect
                    // because the artwork connection pool has not properly
                    // initialized yet.
                    if initialFetch {
                        initialFetch = false
                        try? await Task.sleep(for: .milliseconds(200))
                    }

                    guard let data = try? await ArtworkManager.shared.get(for: song, shouldCache: false) else {
                        artwork = nil
                        return
                    }

                    artwork = PlatformImage(data: data)

                    #if os(iOS)
                        guard let album = try? await mpd.queue.get(for: song, using: .album) as? Album else {
                            return
                        }

                        guard let grouping = try? await ConnectionManager.command().getSongs(for: album) else {
                            return
                        }

                        songs = Dictionary(grouping: grouping, by: { $0.disc })
                    #endif
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 180 + 310 + 650, minHeight: 650)
        .toolbar {
            Color.clear
        }
        #endif
    }
}
