//
//  CategoryDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI
import SwiftUIIntrospect

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

    #if os(macOS)
        // NOTE: Kind of hacky. See https://github.com/feedback-assistant/reports/issues/651
        private let rowHeight: CGFloat

        init(destination: CategoryDestination) {
            self.destination = destination

            rowHeight = switch destination {
            case .albums: 50 + 15
            case .artists: 50 + 15
            case .songs, .playlist: 31.5 + 15
            }
        }
    #endif

    @State private var offset: CGFloat = 0

    @State private var showHeader = false
    @State private var isSearching = false

    #if os(iOS)
        @State private var showSearchButton = false
        @State private var isGoingToSearch = false
        @State private var query = ""
    #elseif os(macOS)
        @State private var hideHeaderTask: Task<Void, Never>?
    #endif

    private let scrollToCurrentNotification = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)
    private let startSearchingNotication = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Group {
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
                .listRowSeparator(.hidden)
                #if os(iOS)
                    .listRowInsets(.init(top: 7.5, leading: 15, bottom: 7.5, trailing: 15))
                #elseif os(macOS)
                    .listRowInsets(.init(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5))
                #endif
            }
            .id(destination)
            .listStyle(.plain)
            // TODO: Replace this safe area stuff with small rows once the rowHeight issue has been fixed.
            .safeAreaPadding(.bottom, 7.5)
            .contentMargins(.vertical, -7.5, for: .scrollIndicators)
            .safeAreaInset(edge: .top, spacing: 7.5) {
                Group {
                    HeaderView(destination: destination, isSearching: $isSearching)
                        .offset(y: showHeader ? 0 : -(50 + 7.5 + 1))
                        .animation(.spring, value: showHeader)
                }
                .frame(height: 50 + 7.5 + 1)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { previous, value in
                guard !isSearching else {
                    return
                }

                guard value > 50 else {
                    offset = 0
                    showHeader = true

                    resetHideHeaderTimer()

                    return
                }

                guard abs(value - offset) > 200 else {
                    if showHeader {
                        resetHideHeaderTimer(offset: value)
                    }

                    return
                }

                offset = value

                if previous < value {
                    if showHeader {
                        showHeader = false
                    }
                } else {
                    if !showHeader {
                        showHeader = true
                    }
                }

                resetHideHeaderTimer()
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
                isSearching = true
            }
            .onChange(of: showHeader) { _, value in
                if value {
                    resetHideHeaderTimer()
                } else {
                    hideHeaderTask?.cancel()
                }
            }
            .onChange(of: isSearching) { _, value in
                if value {
                    showHeader = true
                    hideHeaderTask?.cancel()
                } else {
                    resetHideHeaderTimer()
                }
            }
            .onChange(of: mpd.queue.results?.count) { _, value in
                guard value == nil else {
                    return
                }

                scrollToCurrent(proxy, animate: false)
            }
            #if os(iOS)
            .navigationTitle(destination.label)
            .navigationBarTitleDisplayMode(.large)
            .toolbarVisibility(showToolbar ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if isSearching {
                            isSearching = false
                        } else {
                            isGoingToSearch = true
                        }
                    } label: {
                        Image(systemSymbol: .magnifyingglass)
                            .padding(5)
                    }
                    .opacity(showSearchButton ? 1 : 0)
                }
            }
            .searchable(text: $query, isPresented: $isSearching)
            .disableAutocorrection(true)
            .onChange(of: isSearching) { _, value in
                guard !value else {
                    return
                }

                mpd.queue.results = nil
            }
            .onChange(of: isGoingToSearch) { _, value in
                guard value else {
                    return
                }

                isSearching = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isGoingToSearch = false
                }
            }
            .task(id: query) {
                guard isSearching else {
                    return
                }

                if query.isEmpty {
                    mpd.queue.results = nil
                } else {
                    try? await mpd.queue.search(for: query)
                }
            }
            #elseif os(macOS)
            .environment(\.defaultMinListRowHeight, min(rowHeight, 50))
            #endif
        }
    }

    private func resetHideHeaderTimer(offset: CGFloat) {
        hideHeaderTask?.cancel()
        guard showHeader, !isSearching, offset > 0 else {
            return
        }

        hideHeaderTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, showHeader, !isSearching, offset > 0 else {
                return
            }

            showHeader = false
        }
    }

    private func resetHideHeaderTimer() {
        resetHideHeaderTimer(offset: offset)
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
}
