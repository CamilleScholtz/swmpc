//
//  CategoryDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI
import SwiftUIIntrospect

struct CategoryDestinationView: View {
    let destination: CategoryDestination

    var body: some View {
        switch destination {
        #if os(iOS)
            case .playlists:
                PlaylistsView()
            case .settings:
                SettingsView()
        #endif
        default:
            CategoryView(destination: destination)
        }
    }
}

struct EmptyCategoryView: View {
    let destination: CategoryDestination

    @State private var showIntelligencePlaylistSheet = false
    @State private var playlistToEdit: Playlist?

    private let fillIntelligencePlaylistNotification = NotificationCenter.default
        .publisher(for: .fillIntelligencePlaylistNotification)

    var body: some View {
        VStack {
            switch destination {
            case .albums, .artists, .songs:
                Text("No \(String(localized: destination.label).lowercased()) in library.")
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
        .onReceive(fillIntelligencePlaylistNotification) { notification in
            guard let playlist = notification.object as? Playlist else {
                return
            }
            playlistToEdit = playlist
            showIntelligencePlaylistSheet = true
        }
        .sheet(isPresented: $showIntelligencePlaylistSheet) {
            IntelligenceView(target: .playlist($playlistToEdit), showSheet: $showIntelligencePlaylistSheet)
        }
    }
}

struct CategoryView: View {
    @Environment(MPD.self) private var mpd

    let destination: CategoryDestination

    #if os(macOS)
        private var rowHeight: CGFloat {
            switch destination {
            case .albums, .artists: 65
            case .songs, .playlist: 46.5
            }
        }
    #endif

    #if os(iOS)
        @State private var scrollView: UIScrollView?
    #elseif os(macOS)
        @State private var scrollView: NSScrollView?
    #endif

    @State private var offset: CGFloat = 0

    @State private var showHeader = false
    @State private var isSearching = false
    @State private var searchQuery = ""

    @State private var hideHeaderTask: Task<Void, Never>?

    private let scrollToCurrentNotification = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)
    private let startSearchingNotication = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    var body: some View {
        List {
            if case let .playlist(playlist) = destination {
                MediaView(using: playlist, searchQuery: searchQuery)
            } else {
                MediaView(using: mpd.database, searchQuery: searchQuery)
            }
        }
        .id(destination)
        .listStyle(.plain)
        .task(id: destination) {
            switch destination {
            case .albums:
                try? await mpd.database.set(type: .album, idle: false)
            case .artists:
                try? await mpd.database.set(type: .artist, idle: false)
            case .songs:
                try? await mpd.database.set(type: .song, idle: false)
            default:
                break
            }
        }
        .introspect(.list, on: .macOS(.v15)) { tableView in
            DispatchQueue.main.async {
                scrollView = tableView.enclosingScrollView
            }
        }
        .safeAreaPadding(.bottom, 7.5)
        .contentMargins(.vertical, -7.5, for: .scrollIndicators)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { previous, value in
            guard !isSearching else {
                return
            }

            guard value > 50 else {
                offset = 0
                showHeader = true

                #if os(iOS)
                    showSearchButton = false
                #endif

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
            showHeader = previous >= value

            #if os(iOS)
                showSearchButton = true
            #endif

            resetHideHeaderTimer()
        }
        .onReceive(scrollToCurrentNotification) { notification in
            try? scrollToCurrent(animate: notification.object as? Bool ?? true)
        }
        .onReceive(startSearchingNotication) { _ in
            isSearching = true
        }
        .onChange(of: destination) { _, value in
            switch value {
            case .albums, .artists, .songs:
                mpd.state.isLoading = true
            case let .playlist(playlist):
                mpd.state.isLoading = true

                if playlist.name == "Favorites" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        mpd.state.isLoading = false
                    }
                }
            }

            // try? scrollToCurrent(animate: false)

            // for i in 1 ..< 6 {
            //     DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) {
            //         try? scrollToCurrent(animate: false)
            //     }
            // }

            Task {
                while true {
                    try? await Task.sleep(for: .seconds(0.1))

                    if mpd.database.media != nil {
                        try? scrollToCurrent(animate: false)
                        break
                    }
                }
            }
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
                searchQuery = ""
                resetHideHeaderTimer()
            }
        }
        .onChange(of: searchQuery) { _, value in
            guard value.isEmpty else {
                return
            }

            try? scrollToCurrent(animate: false)
        }
        #if os(iOS)
        .navigationTitle(destination.label)
        .navigationBarTitleDisplayMode(.large)
        .toolbarVisibility(showHeader ? .visible : .hidden, for: .navigationBar)
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
                .animation(.spring, value: showSearchButton)
            }
        }
        .searchable(text: $query, isPresented: $isSearching)
        .disableAutocorrection(true)
        .onChange(of: isSearching) { _, value in
            guard !value else {
                return
            }

            // For playlists, notify to clear search results
            if case .playlist = navigator.category {
                NotificationCenter.default.post(name: .startSearchingNotication, object: "")
            }
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

            // For playlists, search is handled by MediaListView internally
            if case .playlist = navigator.category {
                NotificationCenter.default.post(name: .startSearchingNotication, object: query.isEmpty ? "" : query)
            }
            // For database views, search will be handled by SwiftUI's searchable with filtered views
        }
        #elseif os(macOS)
        .safeAreaInset(edge: .top, spacing: 7.5) {
            Group {
                HeaderView(destination: destination, isSearching: $isSearching, searchQuery: $searchQuery)
                    .offset(y: showHeader ? 0 : -(50 + 7.5 + 1))
            }
            .frame(height: 50 + 7.5 + 1)
        }
        .environment(\.defaultMinListRowHeight, min(rowHeight, 50))
        #endif
        .animation(.spring, value: showHeader)
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

    private func scrollToCurrent(animate: Bool = true) throws {
        guard let scrollView, let song = mpd.status.song else {
            throw ViewError.missingData
        }

        var index: Int?
        switch destination {
        case .albums:
            guard let albums = mpd.database.media as? [Album] else {
                throw ViewError.missingData
            }
            index = albums.firstIndex(where: { $0 == song.album })
        case .artists:
            guard let artists = mpd.database.media as? [Artist] else {
                throw ViewError.missingData
            }
            index = artists.firstIndex(where: { $0.name == song.artist })
        case .songs:
            guard let songs = mpd.database.media as? [Song] else {
                throw ViewError.missingData
            }
            index = songs.firstIndex(where: { $0.url == song.url })
        case .playlist:
            break
        #if os(iOS)
            default:
                throw ViewError.missingData
        #endif
        }

        guard let index else {
            throw ViewError.missingData
        }

        #if os(macOS)
            guard let tableView = scrollView.documentView as? NSTableView else {
                throw ViewError.missingData
            }

            tableView.layoutSubtreeIfNeeded()
            scrollView.layoutSubtreeIfNeeded()

            DispatchQueue.main.async {
                let rect = tableView.frameOfCell(atColumn: 0, row: index)
                let y = rect.midY - (scrollView.frame.height / 2)
                let center = NSPoint(x: 0, y: max(0, y))

                if animate {
                    scrollView.contentView.animator().setBoundsOrigin(center)
                } else {
                    scrollView.contentView.setBoundsOrigin(center)
                }
            }
        #elseif os(iOS)
            let rowSpacing: CGFloat = 15
            let baseRowHeight: CGFloat = switch destination {
            case .albums, .artists: 50
            case .songs, .playlist: 31.5
            default: 31.5
            }
            let rowHeight = baseRowHeight + rowSpacing

            let rowMidY = (CGFloat(index) * rowHeight) + (rowHeight / 2)
            let visibleHeight = scrollView.frame.height
            let centeredOffset = rowMidY - (visibleHeight / 2)

            scrollView.setContentOffset(
                CGPoint(x: 0, y: max(0, centeredOffset)),
                animated: animate
            )
        #endif
    }
}
