//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import ButtonKit
import SwiftUI

enum ViewError: Error {
    case missingData
}

struct AppView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator
    @Environment(\.colorScheme) private var colorScheme

    #if os(iOS)
        @Namespace var namespace
    #endif

    #if os(iOS)
        @State private var showDetailCover = false
        @State private var showSettingsSheet = false
    #elseif os(macOS)
        @State private var showQueuePanel = false
    #endif

    @State private var artwork: PlatformImage?

    var body: some View {
        @Bindable var boundNavigator = navigator

        Group {
            if mpd.status.state == nil {
                ErrorView()
            } else {
                Group {
                    #if os(iOS)
                        TabView(selection: $boundNavigator.category) {
                            ForEach(CategoryDestination.categories) { category in
                                // NOTE: Use SFSafeSymbols version when it is available.
                                // https://github.com/SFSafeSymbols/SFSafeSymbols/issues/138
                                Tab(String(localized: category.label), systemImage: category.symbol.rawValue, value: category) {
                                    NavigationStack(path: $boundNavigator.path) {
                                        CategoryDestinationView(showSettingsSheet: $showSettingsSheet)
                                            .navigationDestination(for: ContentDestination.self) { destination in
                                                ContentDestinationView(destination: destination)
                                            }
                                    }
                                    .overlay(
                                        LoadingView(),
                                    )
                                }
                            }
                        }
                        .tabBarMinimizeBehavior(.onScrollDown)
                        .tabViewBottomAccessory {
                            DetailMiniView(artwork: artwork)
                                .onTapGesture {
                                    showDetailCover.toggle()
                                }
                                .matchedTransitionSource(id: 1, in: namespace)
                        }
                        .fullScreenCover(isPresented: $showDetailCover) {
                            List {
                                DetailView(artwork: artwork)
                                    .frame(height: 600)
                                    .mediaRowStyle()

                                QueueView()
                            }
                            .mediaListStyle()
                            .navigationTransition(.zoom(sourceID: 1, in: namespace))
                        }
                        .sheet(isPresented: $showSettingsSheet) {
                            SettingsView()
                        }
                    #elseif os(macOS)
                        NavigationSplitView {
                            SidebarView()
                                .navigationSplitViewColumnWidth(Layout.Size.sidebarWidth)
                        } content: {
                            NavigationStack(path: $boundNavigator.path) {
                                CategoryDestinationView()
                                    .navigationDestination(for: ContentDestination.self) { destination in
                                        ContentDestinationView(destination: destination)
                                            .navigationTitle(navigator.category.label)
                                    }
                            }
                            .navigationSplitViewColumnWidth(Layout.Size.contentWidth)
                            .overlay(
                                LoadingView(),
                            )
                            .scrollEdgeEffectStyle(.soft, for: .vertical)
                        } detail: {
                            // XXX: The scrollview is a hack to hide the toolbar.
                            ZStack {
                                ScrollView {}
                                    .scrollDisabled(true)

                                DetailView(artwork: artwork, showQueuePanel: $showQueuePanel)
                            }
                            .scrollEdgeEffectStyle(.soft, for: .vertical)
                        }
                        .simultaneousGesture(
                            TapGesture()
                                .onEnded {
                                    guard showQueuePanel else {
                                        return
                                    }

                                    withAnimation(.spring) {
                                        showQueuePanel = false
                                    }
                                },
                        )
                        .overlay(alignment: .trailing) {
                            if showQueuePanel {
                                QueueView()
                                    .frame(width: Layout.Size.contentWidth)
                                    .overlay(
                                        Rectangle()
                                            .ignoresSafeArea(.container, edges: .top)
                                            .frame(width: 1)
                                            .foregroundColor(colorScheme == .dark ? .black : Color(.secondarySystemFill)),
                                        alignment: .leading,
                                    )
                                    .transition(.move(edge: .trailing))
                            }
                        }
                    #endif
                }
            }
        }
        .task(priority: .medium) {
            try? await mpd.status.startTrackingElapsed()
        }
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                artwork = nil
                return
            }

            artwork = try? await song.artwork()
        }
        .onDisappear {
            mpd.status.stopTrackingElapsed()
        }
        #if os(macOS)
        .frame(minWidth: Layout.Size.sidebarWidth + Layout.Size.contentWidth + Layout.Size.detailWidth, minHeight: Layout.Size.detailWidth)
        #endif
    }
}
