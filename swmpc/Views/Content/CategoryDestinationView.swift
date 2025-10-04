//
//  CategoryDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SFSafeSymbols
import SwiftUI

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
                    CategoryPlaylistView(playlist: navigator.category.source.playlist!)
                case .playlist:
                    CategoryPlaylistView(playlist: navigator.category.source.playlist!)
                default:
                    EmptyView()
                }
            }
        }
        #if os(macOS)
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

    @State private var searchQuery = ""
    @State private var searchResults: [any Mediable]?

    #if os(iOS)
        @State private var previousCategory: CategoryDestination?
    #endif

    @FocusState private var isSearchFieldFocused: Bool

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
                mediaList(for: searchResults ?? media)
                    .id(mpd.database.type)
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
                        // XXX: This doesn't work for some reason.
                        .focusEffectDisabled()
                        .autocorrectionDisabled()
                        // XXX: This ALSO doesn't work.
                        // See: https://developer.apple.com/forums/thread/797948
                        // And: https://stackoverflow.com/questions/74245149/focusstate-textfield-not-working-within-toolbar-toolbaritem
                        .focused($isSearchFieldFocused)
                        .onAppear {
                            isSearchFieldFocused = true
                        }
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
                        searchQuery = ""
                        searchResults = nil
                        isSearchFieldFocused = false
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
            #if os(iOS)
                guard navigator.category != previousCategory else {
                    return
                }

                previousCategory = navigator.category
            #endif

            mpd.state.isLoading = true
            try? await mpd.database.set(idle: false, type: navigator.category.type, sort: sort)

            searchQuery = ""
            searchResults = nil

            scrollToCurrentMedia()
            try? await Task.sleep(for: .milliseconds(200))
            scrollToCurrentMedia()
        }
        .task(id: sort) {
            #if os(iOS)
                guard navigator.category != previousCategory else {
                    return
                }
            #endif

            guard !mpd.state.isLoading else {
                return
            }

            mpd.state.isLoading = true
            try? await mpd.database.set(idle: false, sort: sort)

            scrollToCurrentMedia()
            try? await Task.sleep(for: .milliseconds(100))
            scrollToCurrentMedia()
        }
        .onChange(of: searchQuery) { _, query in
            if query.isEmpty {
                searchResults = nil
            } else if !searchFields.isEmpty {
                searchResults = mpd.database.search(query: query, fields: searchFields)
            }
        }
        .onChange(of: searchFields) { _, _ in
            if !searchQuery.isEmpty, !searchFields.isEmpty {
                searchResults = mpd.database.search(query: searchQuery, fields: searchFields)
            } else if searchFields.isEmpty {
                searchResults = nil
            }
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
                .ignoresSafeArea(edges: .vertical)
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
            mpd.state.isLoading = true

            songs = try? await mpd.playlists.getSongs(for: playlist)

            if songIsInPlaylist(mpd.status.song) {
                scrollToCurrentSong()
                try? await Task.sleep(for: .milliseconds(200))
                scrollToCurrentSong()
            }
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
        guard let sourceIndex = indices.first,
              let songs,
              sourceIndex < songs.count
        else {
            return
        }

        let song = songs[sourceIndex]

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
