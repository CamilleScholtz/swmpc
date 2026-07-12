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
#if os(macOS)
    import SwiftUIIntrospect
#endif

struct CategoryDestinationView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    @State private var isSearchFieldExpanded = false

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
                    CategoryDatabaseView(isSearchFieldExpanded: $isSearchFieldExpanded)
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
        .navigationTitle(isSearchFieldExpanded ? "" : navigator.category.label)
        .navigationBarTitleDisplayMode(.inline)
        #elseif os(macOS)
        .navigationTitle(navigator.category.label)
        .toolbar(removing: isSearchFieldExpanded ? .title : nil)
        #endif
        .onChange(of: navigator.category) {
            isSearchFieldExpanded = false
            mpd.state.isLoading = true
        }
    }
}

private struct CategoryDatabaseView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    @AppStorage(Setting.albumSearchFields) private var albumSearchFields = SearchFields.default
    @AppStorage(Setting.artistSearchFields) private var artistSearchFields = SearchFields.default
    @AppStorage(Setting.songSearchFields) private var songSearchFields = SearchFields.default

    @AppStorage(Setting.albumSortOption) private var albumSort = MPDKit.SortDescriptor.default
    @AppStorage(Setting.artistSortOption) private var artistSort = MPDKit.SortDescriptor.default
    @AppStorage(Setting.songSortOption) private var songSort = MPDKit.SortDescriptor.default

    @Binding var isSearchFieldExpanded: Bool

    #if os(iOS)
        @FocusState private var isSearchFieldFocused: Bool
    #endif

    @State private var scrollTarget: ScrollTarget?

    @State private var searchTask: Task<Void, Never>?
    @State private var searchQuery = ""
    @State private var searchResults: [any Mediable]?

    private var searchFields: SearchFields {
        let fields = switch navigator.category {
        case .albums: albumSearchFields
        case .artists: artistSearchFields
        case .songs: songSearchFields
        default: SearchFields.default
        }

        if fields.isEmpty {
            return navigator.category.source.defaultSearchFields(for: navigator.category.type)
        }

        return fields
    }

    private var sort: MPDKit.SortDescriptor {
        switch navigator.category {
        case .albums: albumSort
        case .artists: artistSort
        case .songs: songSort
        default: MPDKit.SortDescriptor.default
        }
    }

    var body: some View {
        Group {
            if let media = mpd.database.media, !media.isEmpty {
                MediaListView(media: searchResults ?? media, type: mpd.database.type, scrollTarget: $scrollTarget)
                    // XXX: `isActive` also guards against the window during a
                    // category switch where the list still shows the previous
                    // category's media: geometry changes there would be
                    // recorded against the new category, wiping its
                    // remembered position.
                    .scrollMemory(for: navigator.category, scrollTarget: scrollTarget,
                                  isActive: searchResults == nil && mpd.database.type == navigator.category.type)
                    .id(navigator.category)
            } else {
                EmptyCategoryView(destination: navigator.category)
            }
        }
        .toolbar {
            if isSearchFieldExpanded {
                ToolbarItem {
                    TextField("Search \(String(localized: navigator.category.label).lowercased())", text: $searchQuery)
                    #if os(macOS)
                        .frame(width: 195.5)
                        .focusEffectDisabled()
                    #endif
                        .padding(.leading, Layout.Padding.small)
                        .autocorrectionDisabled()
                    #if os(iOS)
                        .focused($isSearchFieldFocused)
                    #elseif os(macOS)
                        .introspect(.textField, on: .macOS(.v27)) { value in
                            // XXX: Workaround for .focusEffectDisabled() not working in toolbar.
                            value.focusRingType = .none

                            // XXX: Workaround for @FocusState not working in
                            // toolbar. Force the field to become first responder
                            // once it lands in a window, but leave it alone after
                            // it already has focus so typing isn't interrupted.
                            guard let window = value.window, value.currentEditor() == nil else {
                                return
                            }

                            Task { @MainActor in
                                window.makeFirstResponder(value)
                                value.currentEditor()?.selectedRange = NSRange(location: value.stringValue.count, length: 0)
                            }
                        }
                    #endif
                }

                ToolbarItem {
                    searchFieldsMenu
                }
            } else {
                ToolbarItem {
                    Button("Scroll to Current Media", systemSymbol: .dotViewfinder) {
                        navigator.clearScrollOffset(for: navigator.category)
                        scrollToCurrentMedia(animated: true)
                    }
                    .disabled(mpd.status.song == nil)
                }
            }

            ToolbarSpacer(.fixed)

            #if os(iOS)
                if !isSearchFieldExpanded {
                    ToolbarItem {
                        sortMenu
                    }
                }
            #elseif os(macOS)
                if !isSearchFieldExpanded, navigator.category.source.isSortable {
                    ToolbarItem {
                        sortMenu
                    }
                }
            #endif

            ToolbarItem {
                Button("Search", systemSymbol: isSearchFieldExpanded ? .xmark : .magnifyingglass) {
                    isSearchFieldExpanded.toggle()

                    if !isSearchFieldExpanded {
                        searchTask?.cancel()
                        searchQuery = ""
                        searchResults = nil
                    }
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }
        .task(id: LoadParameters(category: navigator.category, sort: sort)) {
            try? await mpd.database.set(idle: false, type: navigator.category.type, sort: sort)

            searchTask?.cancel()
            searchQuery = ""
            searchResults = nil

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
        .onChange(of: searchQuery) { _, value in
            performSearch(query: value, fields: searchFields)
        }
        .onChange(of: searchFields) { _, value in
            performSearch(query: searchQuery, fields: value)
        }
        #if os(iOS)
        .onChange(of: isSearchFieldExpanded) { _, value in
            isSearchFieldFocused = value
        }
        #endif
    }

    private func performSearch(query: String, fields: SearchFields) {
        searchTask?.cancel()

        guard query.count >= 2, !fields.isEmpty else {
            searchResults = nil
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else {
                return
            }

            let results = await mpd.database.search(query, fields: fields)
            guard !Task.isCancelled else {
                return
            }

            searchResults = results
        }
    }

    private var searchFieldsMenu: some View {
        Menu {
            ForEach(navigator.category.source.availableSearchFields(for: mpd.database.type), id: \.self) { field in
                Toggle(isOn: Binding(
                    get: { searchFields.contains(field) },
                    set: { _ in
                        var newFields = searchFields
                        newFields.toggle(field)

                        switch navigator.category {
                        case .albums: albumSearchFields = newFields
                        case .artists: artistSearchFields = newFields
                        case .songs: songSearchFields = newFields
                        default: break
                        }
                    },
                )) {
                    Label {
                        Text(field.label)
                    } icon: {
                        Image(systemSymbol: field.symbol)
                    }
                }
            }
        } label: {
            Image(systemSymbol: .sliderHorizontal3)
        }
        .menuIndicator(.hidden)
    }

    private var sortMenu: some View {
        Menu {
            if navigator.category.source.isSortable {
                ForEach(navigator.category.source.availableSortOptions(for: navigator.category.type), id: \.self) { (option: SortOption) in
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

        guard let offset = navigator.scrollOffset(for: navigator.category),
              let target = ScrollTarget(restoring: offset, in: mpd.database.media ?? [], rowContentHeight: rowContentHeight)
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

        let id: String? = switch navigator.category.type {
        case .album:
            (media as? [Album])?.first { $0.id == song.album.id }?.id
        case .artist:
            (media as? [Artist])?.first { $0.id == song.album.artist.id }?.id
        default:
            (media as? [Song])?.first { $0.id == song.id }?.id
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
                    .onMove { indices, destination in
                        Task {
                            await handleReorder(indices: indices, destination: destination)
                        }
                    }
                    .mediaRowStyle()
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
        .alert("Replace Queue", isPresented: $showReplaceQueueAlert) {
            Button("Cancel", role: .cancel) {}

            AsyncButton("Replace", role: .destructive) {
                try await ConnectionManager.command {
                    try await $0.loadPlaylist(playlist)
                }
            }
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

    private func handleReorder(indices: IndexSet, destination: Int) async {
        guard let index = indices.first,
              let songs
        else {
            return
        }

        guard index < songs.count else {
            return
        }

        let song = songs[index]

        try? await ConnectionManager.command {
            try await $0.move(song, to: destination, in: navigator.category.source)
        }
        self.songs = try? await mpd.playlists.getSongs(for: playlist)
    }
}

private struct LoadParameters: Equatable {
    let category: CategoryDestination
    let sort: MPDKit.SortDescriptor
}

private struct MediaListView: View {
    let media: [any Mediable]
    let type: MediaType
    @Binding var scrollTarget: ScrollTarget?

    var body: some View {
        Group {
            switch type {
            case .album:
                if let albums = media as? [Album] {
                    List(albums, id: \.id) { album in
                        AlbumView(for: album)
                            .equatable()
                            .mediaRowStyle()
                    }
                    .mediaListStyle(rowHeight: Layout.RowHeight.album)
                }
            case .artist:
                if let artists = media as? [Artist] {
                    List(artists, id: \.id) { artist in
                        ArtistView(for: artist)
                            .equatable()
                            .mediaRowStyle()
                    }
                    .mediaListStyle(rowHeight: Layout.RowHeight.artist)
                }
            default:
                if let songs = media as? [Song] {
                    List(songs, id: \.id) { song in
                        SongView(for: song, source: .database)
                            .equatable()
                            .mediaRowStyle()
                    }
                    .mediaListStyle(rowHeight: Layout.RowHeight.song)
                }
            }
        }
        .scrollToItem($scrollTarget)
    }
}

private struct EmptyCategoryView: View {
    let destination: CategoryDestination

    var body: some View {
        VStack {
            switch destination {
            case .albums, .artists, .songs:
                Text("No \(String(localized: destination.label).lowercased()) in library.")
                    .font(.headline)

                Text("Add songs to your library.")
                    .font(.subheadline)
            case .playlist:
                Text("No songs in playlist.")
                    .font(.headline)
                Text("Add songs to your playlist.")
                    .font(.subheadline)
            #if os(iOS)
                default:
                    EmptyView()
            #endif
            }
        }
        .offset(y: -20)
    }
}
