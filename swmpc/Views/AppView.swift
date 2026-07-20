//
//  AppView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import ButtonKit
import MPDKit
import SwiftUI
import WidgetKit

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

    #if os(macOS)
        @State private var showQueuePanel = false
        @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #endif

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
                                Tab(value: category) {
                                    NavigationStack(path: $navigator[path: category]) {
                                        CategoryDestinationView()
                                            .navigationDestination(for: ContentDestination.self) { destination in
                                                ContentDestinationView(destination: destination)
                                            }
                                    }
                                    .overlay {
                                        LoadingView()
                                    }
                                } label: {
                                    Label {
                                        category.label
                                    } icon: {
                                        Image(systemSymbol: category.symbol)
                                    }
                                }
                            }
                        }
                        .tabViewBottomAccessory {
                            Button {
                                navigator.showNowPlaying.toggle()
                            } label: {
                                DetailMiniView()
                            }
                            .buttonStyle(.plain)
                            .matchedTransitionSource(id: 1, in: namespace)
                        }
                        .fullScreenCover(isPresented: $navigator.showNowPlaying) {
                            List {
                                Capsule()
                                    .fill(.tertiary)
                                    .frame(width: 64, height: 5)
                                    .frame(maxWidth: .infinity)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(.init())
                                    .listRowBackground(Color.clear)

                                DetailView()
                                    .frame(height: 580)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(.horizontal, Layout.Padding.large)

                                QueueView()
                            }
                            .reorderContainer(for: Song.self) { difference in
                                Task {
                                    await difference.perform(on: mpd.queue.songs, in: .queue)
                                }
                            }
                            .mediaListStyle()
                            .navigationTransition(.zoom(sourceID: 1, in: namespace))
                            .sheet(item: $navigator.intelligenceTarget) { target in
                                IntelligenceView(target: target)
                            }
                            .alert("Clear Queue", isPresented: $navigator.showClearQueueAlert) {
                                Button("Cancel", role: .cancel) {}

                                AsyncButton("Clear", role: .destructive) {
                                    try await ConnectionManager.command {
                                        try await $0.clearQueue()
                                    }
                                }
                            } message: {
                                Text("Are you sure you want to clear the queue?")
                            }
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
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .navigationSplitViewColumnWidth(Layout.Size.contentWidth)
                            .overlay {
                                LoadingView()
                            }
                        } detail: {
                            // XXX: The scrollview is a hack to hide apply the scroll edge effect.
                            ZStack {
                                ScrollView {}
                                    .scrollContentBackground(.visible)

                                DetailView(showQueuePanel: $showQueuePanel)
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
                                    .overlay(alignment: .leading) {
                                        Rectangle()
                                            .ignoresSafeArea(.container, edges: .top)
                                            .frame(width: 1)
                                            .foregroundStyle(colorScheme == .dark ? .black : Color(.secondarySystemFill))
                                    }
                                    .transition(.move(edge: .trailing))
                            }
                        }
                    #endif
                }
            }
        }
        .task(priority: .medium) {
            WidgetCenter.shared.reloadAllTimelines()
            try? await mpd.status.startTrackingElapsed()
        }
        .onDisappear {
            mpd.status.stopTrackingElapsed()
        }
        #if os(macOS)
        .alert("Clear Queue", isPresented: $navigator.showClearQueueAlert) {
            Button("Cancel", role: .cancel) {}

            AsyncButton("Clear", role: .destructive) {
                try await ConnectionManager.command {
                    try await $0.clearQueue()
                }
            }
        } message: {
            Text("Are you sure you want to clear the queue?")
        }
        #endif
        .sheet(item: $navigator.intelligenceTarget) { target in
            IntelligenceView(target: target)
        }
        #if os(iOS)
        .sheet(isPresented: $navigator.showSettingsSheet) {
            SettingsView()
        }
        .modifier(ForegroundResyncModifier())
        #elseif os(macOS)
        .frame(minWidth: Layout.Size.sidebarWidth + Layout.Size.contentWidth + Layout.Size.detailWidth, minHeight: Layout.Size.detailWidth)
        #endif
    }
}

#if os(iOS)
    /// Re-syncs MPD state when the app returns to the foreground after having
    /// been backgrounded, since the idle connection may have died while the
    /// app was suspended.
    ///
    /// This lives in its own modifier so that `AppView` itself takes no
    /// `scenePhase` dependency: only this modifier's lightweight body
    /// re-evaluates on scene phase changes.
    private struct ForegroundResyncModifier: ViewModifier {
        @Environment(MPD.self) private var mpd
        @Environment(\.scenePhase) private var scenePhase

        @State private var wasBackgrounded = false

        func body(content: Content) -> some View {
            content
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background:
                        wasBackgrounded = true
                    case .active:
                        guard wasBackgrounded else {
                            return
                        }
                        wasBackgrounded = false

                        Task {
                            await mpd.resync()
                        }
                    default:
                        break
                    }
                }
        }
    }
#endif
