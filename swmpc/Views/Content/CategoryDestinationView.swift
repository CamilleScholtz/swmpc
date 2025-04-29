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
        // NOTE: Kind of hacky. See FB17383923 and https://developer.apple.com/forums/thread/782429
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

    @State private var isSearching = false
    @State private var query = ""

    @State private var offset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 1
    @State private var showHeader = false

    #if os(iOS)
        @State private var showSearchButton = false
        @State private var isGoingToSearch = false
        @State private var query = ""
    #endif

    private let scrollToCurrentNotification = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)
    private let startSearchingNotication = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    private let coordinateSpaceName = "category_view_coordinate_space"

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .topLeading) {
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
                .introspect(.scrollView, on: .macOS(.v15)) { scrollView in
                    scrollView.additionalSafeAreaInsets = NSEdgeInsets(top: 50 - 7.5, left: 0, bottom: 0, right: 0)
                    scrollView.scrollerInsets = NSEdgeInsets(top: -50 + 7.5, left: 0, bottom: 0, right: 0)
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, rowHeight)

                #if os(macOS)
                    if showHeader {
                        HeaderView(destination: destination, isSearching: $isSearching)
                    }
                #endif
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
            .onReceive(startSearchingNotication) { _ in
                scrollToTop(proxy)

                isSearching = true
            }
            #endif
        }
    }

    private func determineScrollDirection(offset: CGFloat) {
        #if os(iOS)
            guard !isGoingToSearch else {
                return
            }
        #endif

        let difference = offset - lastScrollOffset
        let threshold: CGFloat = 10

        if difference < -threshold {
            if showHeader {
                withAnimation(.spring) {
                    showHeader = false
                }
            }
        } else if difference > threshold {
            if !showHeader {
                withAnimation(.spring) {
                    showHeader = true
                }
            }
        }

        #if os(iOS)
            if offset < -20 {
                if !showSearchButton {
                    withAnimation(.interactiveSpring) {
                        showSearchButton = true
                    }
                }
            } else {
                if showSearchButton {
                    withAnimation(.interactiveSpring) {
                        showSearchButton = false
                    }
                }
            }
        #endif

        if abs(difference) > 0.1 {
            lastScrollOffset = offset
        }
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
