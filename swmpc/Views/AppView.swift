//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import NavigatorUI
import SwiftUI

#if os(iOS)
    import LNPopupUI
#endif

struct AppView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator

    @State private var destination: SidebarDestination = .albums

    #if os(iOS)
        @State private var artwork: UIImage?

        @State private var isPopupBarPresented = true
        @State private var isPopupOpen = false
    #elseif os(macOS)
        @State private var artwork: NSImage?
    #endif

    var body: some View {
        Group {
            if mpd.status.state == nil {
                ErrorView()
            } else {
                Group {
                    #if os(iOS)
                        TabView(selection: $destination) {
                            ForEach(SidebarDestination.categories) { category in
                                ManagedNavigationStack {
                                    category
                                        .navigationDestination(ContentDestination.self)
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
                            DetailView(artwork: $artwork, isPopupOpen: $isPopupOpen)
                        }
                        .popupBarProgressViewStyle(.top)
                    #elseif os(macOS)
                        NavigationSplitView {
                            SidebarView(destination: $destination)
                                .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: .infinity)
                        } content: {
                            ManagedNavigationStack(name: "content") {
                                destination
                                    .navigationDestination(ContentDestination.self)
                            }
                            .navigationSplitViewColumnWidth(310)
                            .navigationBarBackButtonHidden(true)
                            .ignoresSafeArea()
                            .overlay(
                                LoadingView(destination: $destination)
                            )
                        } detail: {
                            ViewThatFits {
                                DetailView(artwork: $artwork)
                            }
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

                    #if os(iOS)
                        artwork = UIImage(data: data)
                    #elseif os(macOS)
                        artwork = NSImage(data: data)
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
