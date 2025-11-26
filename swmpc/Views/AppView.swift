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
    #elseif os(macOS)
        @State private var showQueuePanel = false
        @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #endif

    @State private var artwork: PlatformImage?
    @State private var showClearQueueAlert = false

    private let showClearQueueAlertNotification = NotificationCenter.default
        .publisher(for: .showClearQueueAlertNotification)

    var body: some View {
        @Bindable var navigator = navigator

        Group {
            if !mpd.state.isConnectionReady {
                ErrorView()
            } else {
                Group {
                    #if os(iOS)
                        TabView(selection: $navigator.category) {
                            ForEach(CategoryDestination.categories) { category in
                                Tab(String(localized: category.label), systemSymbol: category.symbol, value: category) {
                                    NavigationStack(path: $navigator.path) {
                                        CategoryDestinationView()
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
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(.horizontal, Layout.Padding.large)

                                QueueView()
                            }
                            .mediaListStyle()
                            .navigationTransition(.zoom(sourceID: 1, in: namespace))
                        }
                    #elseif os(macOS)
                        NavigationSplitView(columnVisibility: $columnVisibility) {
                            SidebarView()
                                .navigationSplitViewColumnWidth(Layout.Size.sidebarWidth)
                        } content: {
                            NavigationStack(path: $navigator.path) {
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
                            // XXX: The scrollview is a hack to hide apply the .soft scroll edge effect.
                            ZStack {
                                ScrollView {}
                                    .scrollContentBackground(.visible)

                                DetailView(artwork: artwork, showQueuePanel: $showQueuePanel)
                            }
                            .scrollEdgeEffectStyle(.soft, for: .vertical)
                        }
                        .onChange(of: columnVisibility) { _, value in
                            // XXX: Little hacky, is there not some setting?
                            if value != .all {
                                columnVisibility = .all
                            }
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
        .alert("Clear Queue", isPresented: $showClearQueueAlert) {
            Button("Cancel", role: .cancel) {}

            AsyncButton("Clear", role: .destructive) {
                try await ConnectionManager.command {
                    try await $0.clearQueue()
                }
            }
        } message: {
            Text("Are you sure you want to clear the queue?")
        }
        .onReceive(showClearQueueAlertNotification) { _ in
            showClearQueueAlert = true
        }
        #if os(iOS)
        .sheet(isPresented: $navigator.showSettingsSheet) {
            SettingsView()
        }
        #elseif os(macOS)
        .frame(minWidth: Layout.Size.sidebarWidth + Layout.Size.contentWidth + Layout.Size.detailWidth, minHeight: Layout.Size.detailWidth)
        #endif
    }
}
