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
    @Environment(NavigationManager.self) private var navigator

    @State private var artwork: PlatformImage?

    #if os(iOS)
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
                                NavigationStack(path: $boundNavigator.path) {
                                    CategoryDestinationView(destination: category)
                                        .navigationDestination(for: ContentDestination.self) { destination in
                                            ContentDestinationView(destination: destination)
                                        }
                                }
                                .tabItem {
                                    Label(category.label, systemSymbol: category.symbol)
                                }
                                .tag(category)
                            }
                            .overlay(
                                LoadingView()
                            )
                        }
                        .handleQueueChange()
                        .popup(isBarPresented: $isPopupBarPresented, isPopupOpen: $isPopupOpen) {
                            DetailView(artwork: artwork, isPopupOpen: $isPopupOpen)
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

                    guard let data = try? await ArtworkManager.shared.get(for: song, shouldCache: false) else {
                        artwork = nil
                        return
                    }

                    artwork = PlatformImage(data: data)
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
