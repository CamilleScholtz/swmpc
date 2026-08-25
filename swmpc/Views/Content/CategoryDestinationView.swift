//
//  CategoryDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import MPDKit
import SFSafeSymbols
import SwiftUI

struct CategoryDestinationView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    var body: some View {
        Group {
            switch navigator.category {
            #if os(iOS)
                case .playlists:
                    PlaylistsView()
            #endif
            default:
                switch navigator.category.source {
                case .database:
                    CategoryDatabaseView()
                case .favorites:
                    if let playlist = navigator.category.source.playlist {
                        CategoryPlaylistView(playlist: playlist)
                    }
                case .playlist:
                    if let playlist = navigator.category.source.playlist {
                        CategoryPlaylistView(playlist: playlist)
                    }
                default:
                    EmptyView()
                }
            }
        }
        #if os(iOS)
        .navigationTitle(navigator.category.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
        #elseif os(macOS)
        .navigationTitle(navigator.category.label)
        #endif
        .onChange(of: navigator.category) { _, value in
            #if os(iOS)
                guard value != .search else {
                    return
                }
            #endif

            mpd.state.isLoading = true
        }
    }
}

private struct CategoryDatabaseView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    @AppStorage(Setting.albumSortOption) private var albumSort = MPDKit.SortDescriptor.default
    @AppStorage(Setting.artistSortOption) private var artistSort = MPDKit.SortDescriptor.default
    @AppStorage(Setting.songSortOption) private var songSort = MPDKit.SortDescriptor.default

    @State private var scrollTarget: ScrollTarget?

    #if os(macOS)
        @State private var isSearchFieldExpanded = false
        @State private var searchQuery = ""
    #endif

    private var sort: MPDKit.SortDescriptor {
        let stored: MPDKit.SortDescriptor = switch navigator.category {
        case .albums: albumSort
        case .artists: artistSort
        case .songs: songSort
        default: MPDKit.SortDescriptor.default
        }

        return stored.resolved(on: mpd.state)
    }

    /// The sort options the server is new enough to apply.
    ///
    /// Options whose tag the server does not know are hidden rather than
    /// offered and quietly ignored.
    private var sortOptions: [SortOption] {
        guard navigator.category.source.isSortable else {
            return []
        }

        return navigator.category.source
            .availableSortOptions(for: navigator.category.type)
            .filter { mpd.state.supports(minimumVersion: $0.minimumVersion) }
    }

    /// Whether the user's scroll position is recorded.
    ///
    /// This guards against the window during a category switch where the list
    /// still shows the previous category's media: geometry changes there
    /// would be recorded against the new category, wiping its remembered
    /// position.
    private var isScrollMemoryActive: Bool {
        mpd.database.type == navigator.category.type
    }

    private var scrollToCurrentMediaButton: some View {
        Button("Scroll to Current Media", systemSymbol: .dotViewfinder) {
            navigator.clearScrollOffset(for: navigator.category)
            scrollToCurrentMedia(animated: true)
        }
        .disabled(mpd.status.song == nil)
    }

    /// The list of media in the current category.
    ///
    /// The scroll position is restored whenever the list appears, so that
    /// dismissing a search on macOS returns to where the user was browsing
    /// rather than to the top.
    @ViewBuilder
    private var mediaList: some View {
        if let media = mpd.database.media, !media.isEmpty {
            MediaListView(media: media, scrollTarget: $scrollTarget)
                .scrollMemory(for: navigator.category, scrollTarget: scrollTarget,
                              isActive: isScrollMemoryActive)
                .id(navigator.category)
                .task {
                    _ = restoreScrollPosition()
                }
        } else {
            EmptyCategoryView(destination: navigator.category)
        }
    }

    var body: some View {
        Group {
            #if os(iOS)
                mediaList
            #elseif os(macOS)
                LibrarySearchView(query: searchQuery, preferredType: navigator.category.type) {
                    mediaList
                }
                .safeAreaPadding(.top, isSearchFieldExpanded ? SearchFieldMetrics.reservedHeight : 0)
            #endif
        }
        #if os(macOS)
        .overlay(alignment: .top) {
            if isSearchFieldExpanded {
                SearchFieldView(text: $searchQuery, prompt: "Artists, albums, and songs") {
                    setSearchFieldExpanded(false)
                } accessory: {
                    SearchFieldsMenu()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        #endif
        .toolbar {
            #if os(iOS)
                ToolbarItem {
                    scrollToCurrentMediaButton
                }

                ToolbarSpacer(.fixed)

                ToolbarItem {
                    sortMenu
                }
            #elseif os(macOS)
                ToolbarItem {
                    scrollToCurrentMediaButton
                }

                ToolbarSpacer(.fixed)

                if navigator.category.source.isSortable {
                    ToolbarItem {
                        sortMenu
                    }
                }

                ToolbarItem {
                    Button {
                        setSearchFieldExpanded(!isSearchFieldExpanded)
                    } label: {
                        Image(systemSymbol: isSearchFieldExpanded ? .xmark : .magnifyingglass)
                            .frame(width: Layout.Size.toolbarSymbol)
                    }
                    .accessibilityLabel(Text("Search"))
                }
            #endif
        }
        #if os(macOS)
        .task {
            for await _ in NotificationCenter.default.notifications(named: .startSearchingNotication) {
                setSearchFieldExpanded(true)
            }
        }
        #endif
        .task(id: LoadParameters(category: navigator.category, sort: sort)) {
            #if os(iOS)
                guard navigator.category != .search else {
                    return
                }
            #endif

            try? await mpd.database.set(idle: false, type: navigator.category.type, sort: sort)

            #if os(macOS)
                setSearchFieldExpanded(false)
            #endif

            if !restoreScrollPosition() {
                scrollToCurrentMedia()
            }
        }
        .onChange(of: mpd.status.song) { old, new in
            guard old == nil, new != nil,
                  navigator.scrollOffset(for: navigator.category) == nil
            else {
                return
            }

            scrollToCurrentMedia()
        }
        .onChange(of: LoadParameters(category: navigator.category, sort: sort)) { old, new in
            // Only react to sort changes within the same category: `sort` is
            // computed from the category, so it also changes when switching
            // to a category with a different sort descriptor, and clearing
            // then would wipe that category's remembered scroll position.
            // Same category here implies the sort is what changed.
            guard old.category == new.category else {
                return
            }

            navigator.clearScrollOffset(for: new.category)
            mpd.state.isLoading = true
        }
    }

    #if os(macOS)
        /// Shows or hides the search field, discarding the query when it is
        /// hidden so that the category list comes back.
        ///
        /// - Parameter expanded: Whether the field is shown.
        private func setSearchFieldExpanded(_ expanded: Bool) {
            withAnimation(.snappy) {
                isSearchFieldExpanded = expanded
            }

            if !expanded {
                searchQuery = ""
            }
        }
    #endif

    private var sortMenu: some View {
        Menu {
            if !sortOptions.isEmpty {
                ForEach(sortOptions, id: \.self) { (option: SortOption) in
                    Button {
                        let newSort = if sort.option == option {
                            MPDKit.SortDescriptor(option: option, direction: sort.direction == .ascending ? .descending : .ascending)
                        } else {
                            MPDKit.SortDescriptor(option: option)
                        }

                        switch navigator.category {
                        case .albums: albumSort = newSort
                        case .artists: artistSort = newSort
                        case .songs: songSort = newSort
                        default: break
                        }
                    } label: {
                        if sort.option == option {
                            Image(systemSymbol: .checkmark)
                        }

                        Text(option.label)

                        if sort.option == option {
                            Text(sort.direction.label)
                        }
                    }
                }

                #if os(iOS)
                    Divider()
                #endif
            }

            #if os(iOS)
                Button {
                    navigator.showSettingsSheet = true
                } label: {
                    Label("Settings", systemSymbol: .gearshape)
                }
            #endif
        } label: {
            #if os(iOS)
                Image(systemSymbol: .ellipsis)
            #elseif os(macOS)
                Image(systemSymbol: .line3HorizontalDecrease)
            #endif
        }
        .menuIndicator(.hidden)
        #if os(iOS)
        .accessibilityLabel(Text("More Options"))
        #elseif os(macOS)
        .accessibilityLabel(Text("Sort"))
        #endif
    }

    /// Restores the scroll position the user last browsed to in the current
    /// category.
    ///
    /// - Returns: `true` if a remembered position was restored, `false` when
    ///            the user hasn't manually scrolled the category.
    private func restoreScrollPosition() -> Bool {
        let rowContentHeight: CGFloat = switch navigator.category.type {
        case .album: Layout.RowHeight.album
        case .artist: Layout.RowHeight.artist
        default: Layout.RowHeight.song
        }

        guard let media = mpd.database.media,
              let offset = navigator.scrollOffset(for: navigator.category),
              let target = ScrollTarget(restoring: offset, in: media, rowContentHeight: rowContentHeight)
        else {
            return false
        }

        scrollTarget = target

        return true
    }

    private func scrollToCurrentMedia(animated: Bool = false) {
        guard let song = mpd.status.song,
              let media = mpd.database.media
        else {
            return
        }

        let id: String? = switch media {
        case let .albums(albums):
            albums.first { $0.id == song.album.id }?.id
        case let .artists(artists):
            artists.first { $0.id == song.album.artist.id }?.id
        case let .songs(songs):
            songs.first { $0.id == song.id }?.id
        }

        guard let id else {
            return
        }

        scrollTarget = ScrollTarget(id: id, animated: animated)
    }
}

struct CategoryPlaylistView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    let playlist: Playlist

    @State private var songs: [Song]?
    @State private var loadedPlaylist: Playlist?
    @State private var scrollTarget: ScrollTarget?
    @State private var showReplaceQueueAlert = false

    var body: some View {
        Group {
            if let songs, !songs.isEmpty {
                List {
                    ForEach(songs) { song in
                        SongView(for: song, source: navigator.category.source)
                            .equatable()
                    }
                    .reorderable()
                    .mediaRowStyle()
                }
                .reorderContainer(for: Song.self) { difference in
                    Task {
                        await difference.perform(on: songs, in: navigator.category.source)
                        self.songs = try? await mpd.playlists.getSongs(for: playlist)
                    }
                }
                .mediaListStyle(rowHeight: Layout.RowHeight.song)
                .scrollToItem($scrollTarget)
                // XXX: `isActive` guards against the window during a playlist
                // switch where the list still shows the previous playlist's
                // songs; see `CategoryDatabaseView`.
                .scrollMemory(for: .playlist(playlist), scrollTarget: scrollTarget,
                              isActive: loadedPlaylist == playlist)
                .id(playlist)
            } else {
                EmptyCategoryView(destination: navigator.category)
            }
        }
        .toolbar {
            if songs?.isEmpty ?? true {
                ToolbarItem {
                    Button("Fill playlist with AI", systemSymbol: IntelligenceManager.symbol) {
                        navigator.intelligenceTarget = .playlist(playlist)
                    }
                    .disabled(!IntelligenceManager.isEnabled)
                }
            } else {
                ToolbarItem {
                    Button("Scroll to Current Song", systemSymbol: .dotViewfinder) {
                        navigator.clearScrollOffset(for: .playlist(playlist))
                        scrollToCurrentSong(animated: true)
                    }
                    .disabled(mpd.status.song == nil || !songIsInPlaylist(mpd.status.song))
                }

                ToolbarSpacer(.fixed)

                ToolbarItem {
                    Button("Replace Queue", systemSymbol: .square3Layers3d) {
                        showReplaceQueueAlert = true
                    }
                }
            }
        }
        .task(id: playlist) {
            songs = try? await mpd.playlists.getSongs(for: playlist)
            loadedPlaylist = playlist

            if !restoreScrollPosition(), songIsInPlaylist(mpd.status.song) {
                scrollToCurrentSong()
            }
        }
        .task(id: playlist) {
            for await _ in NotificationCenter.default.notifications(named: .playlistModifiedNotification) {
                if playlist.name == "Favorites" {
                    try? await mpd.playlists.set(idle: false)
                    songs = mpd.playlists.favorites
                } else {
                    songs = try? await mpd.playlists.getSongs(for: playlist)
                }
            }
        }
        .onChange(of: playlist) {
            mpd.state.isLoading = true
        }
        .confirmationDialog("Replace Queue", isPresented: $showReplaceQueueAlert, titleVisibility: .visible) {
            AsyncButton("Replace", role: .destructive) {
                try await ConnectionManager.command {
                    try await $0.loadPlaylist(playlist)
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to replace the current queue with this playlist?")
        }
    }

    /// Restores the scroll position the user last browsed to in this
    /// playlist.
    ///
    /// - Returns: `true` if a remembered position was restored, `false` when
    ///            the user hasn't manually scrolled the playlist.
    private func restoreScrollPosition() -> Bool {
        guard let offset = navigator.scrollOffset(for: .playlist(playlist)),
              let target = ScrollTarget(restoring: offset, in: songs ?? [], rowContentHeight: Layout.RowHeight.song)
        else {
            return false
        }

        scrollTarget = target

        return true
    }

    private func scrollToCurrentSong(animated: Bool = false) {
        guard let song = mpd.status.song,
              let songs,
              songs.contains(where: { $0.id == song.id })
        else {
            return
        }

        scrollTarget = ScrollTarget(id: song.id, animated: animated)
    }

    private func songIsInPlaylist(_ song: Song?) -> Bool {
        guard let song, let songs else {
            return false
        }

        return songs.contains { $0.id == song.id }
    }
}

private struct LoadParameters: Equatable {
    let category: CategoryDestination
    let sort: MPDKit.SortDescriptor
}

private struct MediaListView: View {
    @Environment(MPD.self) private var mpd

    let media: MediaCollection
    @Binding var scrollTarget: ScrollTarget?

    var body: some View {
        Group {
            switch media {
            case let .albums(albums):
                List(albums, id: \.id) { album in
                    AlbumView(for: album)
                        .equatable()
                        .mediaRowStyle()
                }
                .mediaListStyle(rowHeight: Layout.RowHeight.album)
            case let .artists(artists):
                let albumCounts = mpd.database.artistAlbumCounts

                List(artists, id: \.id) { artist in
                    ArtistView(for: artist, albumCount: albumCounts[artist.id] ?? 0)
                        .equatable()
                        .mediaRowStyle()
                }
                .mediaListStyle(rowHeight: Layout.RowHeight.artist)
            case let .songs(songs):
                List(songs, id: \.id) { song in
                    SongView(for: song, source: .database)
                        .equatable()
                        .mediaRowStyle()
                }
                .mediaListStyle(rowHeight: Layout.RowHeight.song)
            }
        }
        .scrollToItem($scrollTarget)
    }
}

private struct EmptyCategoryView: View {
    let destination: CategoryDestination

    private var title: LocalizedStringResource {
        switch destination {
        case .albums: "No albums in library."
        case .artists: "No artists in library."
        case .playlist: "No songs in playlist."
        default: "No songs in library."
        }
    }

    private var description: LocalizedStringResource {
        switch destination {
        case .playlist: "Add songs to your playlist."
        default: "Add songs to your library."
        }
    }

    var body: some View {
        EmptyStateView(symbol: destination.symbol, title: title, description: description)
    }
}
