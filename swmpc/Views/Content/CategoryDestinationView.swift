//
//  CategoryDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SFSafeSymbols
import SwiftUI
#if os(macOS)
    import SwiftUIIntrospect
#endif

struct CategoryDestinationView: View {
    @Environment(NavigationManager.self) private var navigator
    #if os(macOS)
        @Environment(\.controlActiveState) private var controlActiveState
    #endif

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
                    } else {
                        EmptyView()
                    }
                case .playlist:
                    if let playlist = navigator.category.source.playlist {
                        CategoryPlaylistView(playlist: playlist)
                    } else {
                        EmptyView()
                    }
                default:
                    EmptyView()
                }
            }
        }
        .navigationTitle(navigator.category.label)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #elseif os(macOS)
            .toolbar(removing: .title)
            .toolbar {
                if !isSearchFieldExpanded {
                    // XXX: I want to use DefaultToolbarItem, but that does not work for some reason.
                    ToolbarItem {
                        Text(navigator.category.label)
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .padding(.leading, 12)
                            .foregroundStyle(controlActiveState == .inactive ? .secondary : .primary)
                    }
                    .sharedBackgroundVisibility(.hidden)

                    ToolbarSpacer(.flexible)
                }
            }
        #endif
            .onChange(of: navigator.category) {
                isSearchFieldExpanded = false
            }
    }
}

struct CategoryDatabaseView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    @AppStorage(Setting.albumSearchFields) private var albumSearchFields = SearchFields.default
    @AppStorage(Setting.artistSearchFields) private var artistSearchFields = SearchFields.default
    @AppStorage(Setting.songSearchFields) private var songSearchFields = SearchFields.default

    @AppStorage(Setting.albumSortOption) private var albumSort = SortDescriptor.default
    @AppStorage(Setting.artistSortOption) private var artistSort = SortDescriptor.default
    @AppStorage(Setting.songSortOption) private var songSort = SortDescriptor.default

    @Binding var isSearchFieldExpanded: Bool

    @State private var scrollTarget: ScrollTarget?

    @State private var searchTask: Task<Void, Never>?
    @State private var searchQuery = ""
    @State private var searchResults: [any Mediable]?

    @State private var previousCategory: CategoryDestination?

    #if os(macOS)
        @State private var searchTextField: NSTextField?
    #endif

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

    private var sort: SortDescriptor {
        switch navigator.category {
        case .albums: albumSort
        case .artists: artistSort
        case .songs: songSort
        default: SortDescriptor.default
        }
    }

    @ViewBuilder
    private func mediaList(for media: [any Mediable]) -> some View {
        Group {
            switch mpd.database.type {
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

    var body: some View {
        Group {
            if let media = mpd.database.media, !media.isEmpty {
                mediaList(for: media)
                    .id(navigator.category)
                    .overlay {
                        if let searchResults {
                            mediaList(for: searchResults)
                        }
                    }
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
                    #endif
                        .padding(.leading, Layout.Padding.small)
                        .autocorrectionDisabled()
                    #if os(macOS)
                        .introspect(.textField, on: .macOS(.v26)) { textField in
                            // XXX: Workaround for .focusEffectDisabled() not working in toolbar.
                            textField.focusRingType = .none

                            searchTextField = textField
                        }
                    #endif
                }

                ToolbarItem {
                    searchFieldsMenu
                }
            } else {
                ToolbarItem {
                    Button("Scroll to Current Media", systemSymbol: .dotViewfinder) {
                        scrollToCurrentMedia(animated: true)
                    }
                    .disabled(mpd.status.song == nil)
                }
            }

            ToolbarSpacer(.fixed)

            #if os(macOS)
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

            #if os(iOS)
                if !isSearchFieldExpanded {
                    ToolbarItem {
                        sortMenu
                    }
                }
            #endif
        }
        .task(id: navigator.category) {
            try? await mpd.database.set(idle: false, type: navigator.category.type, sort: sort)

            searchTask?.cancel()
            searchQuery = ""
            searchResults = nil

            scrollToCurrentMedia()
            try? await Task.sleep(for: .milliseconds(200))
            scrollToCurrentMedia()
        }
        .task(id: sort) {
            guard previousCategory == navigator.category else {
                return
            }

            try? await mpd.database.set(idle: false, sort: sort)

            scrollToCurrentMedia()
            try? await Task.sleep(for: .milliseconds(200))
            scrollToCurrentMedia()
        }
        // XXX: I'd prefer to do this in a `Task.immediate`, but I can't modify the `.task` Task.
        .onAppear {
            mpd.state.isLoading = true
        }
        .onChange(of: navigator.category) {
            mpd.state.isLoading = true
            previousCategory = navigator.category
        }
        .onChange(of: sort) {
            mpd.state.isLoading = true
        }
        .onChange(of: searchQuery) { _, value in
            performSearch(query: value, fields: searchFields)
        }
        .onChange(of: searchFields) { _, value in
            performSearch(query: searchQuery, fields: value)
        }
        #if os(macOS)
        // XXX: Workaround for @FocusState not working in toolbar.
        .onChange(of: searchTextField) { _, value in
            guard let value else {
                return
            }

            value.window?.makeFirstResponder(value)
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

    @ViewBuilder
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

    @ViewBuilder
    private var sortMenu: some View {
        Menu {
            if navigator.category.source.isSortable {
                ForEach(navigator.category.source.availableSortOptions(for: navigator.category.type), id: \.self) { option in
                    Button {
                        let newSort = if sort.option == option {
                            SortDescriptor(option: option, direction: sort.direction == .ascending ? .descending : .ascending)
                        } else {
                            SortDescriptor(option: option)
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
                    navigator.showSettings()
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

    private func scrollToCurrentMedia(animated: Bool = false) {
        guard let song = mpd.status.song else {
            return
        }

        let id = switch navigator.category.type {
        case .album:
            song.album.id
        case .artist:
            song.album.artist.id
        default:
            song.id
        }

        scrollTarget = ScrollTarget(id: id, animated: animated)
    }
}

struct CategoryPlaylistView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    let playlist: Playlist

    @State private var songs: [Song]?
    @State private var scrollTarget: ScrollTarget?
    @State private var showIntelligencePlaylistSheet = false
    @State private var playlistToEdit: Playlist?
    @State private var showReplaceQueueAlert = false

    private let fillIntelligencePlaylistNotification = NotificationCenter.default
        .publisher(for: .fillIntelligencePlaylistNotification)
    private let playlistModifiedNotification = NotificationCenter.default
        .publisher(for: .playlistModifiedNotification)

    var body: some View {
        Group {
            if let songs, !songs.isEmpty {
                List {
                    ForEach(songs) { song in
                        SongView(for: song, source: navigator.category.source)
                            .equatable()
                            .id(song.id)
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
                .id(playlist)
            } else {
                EmptyCategoryView(destination: navigator.category)
            }
        }
        .toolbar {
            if songs?.isEmpty ?? true {
                ToolbarItem {
                    Button("Fill playlist with AI", systemSymbol: .sparkles) {
                        NotificationCenter.default.post(name: .fillIntelligencePlaylistNotification, object: playlist)
                    }
                    .disabled(!IntelligenceManager.isEnabled)
                }
            } else {
                ToolbarItem {
                    Button("Scroll to Current Song", systemSymbol: .dotViewfinder) {
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

            if songIsInPlaylist(mpd.status.song) {
                scrollToCurrentSong()
                try? await Task.sleep(for: .milliseconds(200))
                scrollToCurrentSong()
            }
        }
        // XXX: I'd prefer to do this in a `Task.immediate`, but I can't modify the `.task` Task.
        .onAppear {
            mpd.state.isLoading = true
        }
        .onChange(of: playlist) {
            mpd.state.isLoading = true
        }
        .onReceive(fillIntelligencePlaylistNotification) { notification in
            guard let playlist = notification.object as? Playlist else {
                return
            }
            playlistToEdit = playlist
            showIntelligencePlaylistSheet = true
        }
        .onReceive(playlistModifiedNotification) { _ in
            Task(priority: .userInitiated) {
                if playlist.name == "Favorites" {
                    try? await mpd.playlists.set(idle: false)
                    songs = mpd.playlists.favorites
                } else {
                    songs = try? await mpd.playlists.getSongs(for: playlist)
                }
            }
        }
        .sheet(isPresented: $showIntelligencePlaylistSheet) {
            IntelligenceView(target: .playlist($playlistToEdit), showSheet: $showIntelligencePlaylistSheet)
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

    private func scrollToCurrentSong(animated: Bool = false) {
        guard let song = mpd.status.song else {
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

struct EmptyCategoryView: View {
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
