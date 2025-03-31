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

struct AppView: View {
    @Environment(MPD.self) private var mpd

    @State private var pathManager = PathManager()
    @State private var destination: SidebarDestination = .albums

    #if os(iOS)
        @State private var isPopupBarPresented = true
        @State private var isPopupOpen = false
    #endif

    var body: some View {
        Group {
            if mpd.status.state == nil {
                ErrorView()
            } else {
                #if os(iOS)
                    TabView(selection: $destination) {
                        ForEach(SidebarDestination.categories) { category in
                            NavigationStack(path: pathManager.path(for: category)) {
                                SidebarDestinationViewBuilder(destination: category)
                                    .navigationDestination(for: ContentDestination.self) { destination in
                                        ContentDestinationViewBuilder(destination: destination)
                                    }
                            }
                            .tabItem {
                                Label(category.label, systemSymbol: category.symbol)
                            }
                            .tag(category)
                        }
                        .overlay(
                            LoadingView(destination: $destination)
                        )
                    }
                    .handleQueueChange(destination: $destination)
                    .popup(isBarPresented: $isPopupBarPresented, isPopupOpen: $isPopupOpen) {
                        DetailView()
                    }
                    .popupBarProgressViewStyle(.top)
                #elseif os(macOS)
                    NavigationSplitView {
                        SidebarView(destination: $destination)
                            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: .infinity)
                    } content: {
                        NavigationStack(path: $pathManager.contentPath) {
                            SidebarDestinationViewBuilder(destination: destination)
                                .navigationDestination(for: ContentDestination.self) { destination in
                                    ContentDestinationViewBuilder(destination: destination)
                                }
                        }
                        .navigationSplitViewColumnWidth(310)
                        .navigationBarBackButtonHidden(true)
                        .ignoresSafeArea()
                        .overlay(
                            LoadingView(destination: $destination)
                        )
                    } detail: {
                        ViewThatFits {
                            DetailView()
                        }
                        .padding(60)
                    }
                    .background(.background)
                #endif
            }
        }
        .environment(pathManager)
        // Destination is now tracked at view level, not in Status
        #if os(macOS)
        .frame(minWidth: 180 + 310 + 650, minHeight: 650)
        .toolbar {
            Color.clear
        }
        #endif
    }
}

// Helper view builders for SidebarDestination
private struct SidebarDestinationViewBuilder: View {
    @Environment(MPD.self) private var mpd

    let destination: SidebarDestination

    var body: some View {
        #if os(iOS)
            switch destination {
            case .playlists:
                EmptyView()
            case .settings:
                SettingsView()
            default:
                if mpd.queue.internalMedia.isEmpty {
                    EmptyContentView(destination: destination)
                } else {
                    ContentView(destination: destination)
                }
            }
        #elseif os(macOS)
            if mpd.queue.internalMedia.isEmpty {
                EmptyContentView(destination: destination)
            } else {
                ContentView(destination: destination)
            }
        #endif
    }
}

// Helper view builder for ContentDestination
private struct ContentDestinationViewBuilder: View {
    let destination: ContentDestination

    var body: some View {
        ScrollView {
            #if os(iOS)
                let spacing: CGFloat = 10
            #elseif os(macOS)
                let spacing: CGFloat = 15
            #endif

            VStack(alignment: .leading, spacing: spacing) {
                #if os(macOS)
                    BackButtonView()
                        .padding(.top, 12)
                        .offset(y: 5)
                #endif

                switch destination {
                case let .album(album):
                    AlbumSongsView(for: album)
                    #if os(macOS)
                        .padding(.top, 5)
                    #endif
                case let .artist(artist):
                    ArtistAlbumsView(for: artist)
                    #if os(macOS)
                        .padding(.top, 5)
                    #endif
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 15)
        }
        #if os(macOS)
        .ignoresSafeArea()
        #endif
    }
}
