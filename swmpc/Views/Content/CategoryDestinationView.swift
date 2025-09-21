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

    @AppStorage(Setting.albumSortOption) private var albumSort = SortDescriptor(option: .artist)
    @AppStorage(Setting.artistSortOption) private var artistSort = SortDescriptor(option: .artist)
    @AppStorage(Setting.songSortOption) private var songSort = SortDescriptor(option: .album)

    @Binding var isSearchFieldExpanded: Bool

    @State private var scrollTarget: ScrollTarget?

    @State private var searchFields = SearchFields()
    @State private var searchQuery = ""
    @State private var searchResults: [any Mediable]?

    @FocusState private var isSearchFieldFocused: Bool

    private var sort: SortDescriptor {
        switch navigator.category {
        case .albums: albumSort
        case .artists: artistSort
        case .songs: songSort
        default: SortDescriptor(option: .artist)
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
                    .mediaListStyle(rowHeight: Layout.RowHeight.album + Layout.Padding.large)
                }
            case .artist:
                if let artists = media as? [Artist] {
                    List(artists, id: \.id) { artist in
                        ArtistView(for: artist)
                            .equatable()
                            .mediaRowStyle()
                    }
                    .mediaListStyle(rowHeight: Layout.RowHeight.artist + Layout.Padding.large)
                }
            default:
                if let songs = media as? [Song] {
                    List(songs, id: \.id) { song in
                        SongView(for: song, source: .database)
                            .equatable()
                            .mediaRowStyle()
                    }
                    .mediaListStyle(rowHeight: Layout.RowHeight.song + Layout.Padding.large)
                }
            }
        }
        .scrollToItem($scrollTarget)
    }

    var body: some View {
        ZStack {
            if let searchResults {
                mediaList(for: searchResults)
                    .id(mpd.database.type)
            } else if let media = mpd.database.media, !media.isEmpty {
                mediaList(for: media)
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

            if !isSearchFieldExpanded, navigator.category.source.isSortable {
                ToolbarItem {
                    sortMenu
                }
            }

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
        }
        .task(id: navigator.category) {
            mpd.state.isLoading = true
            try? await mpd.database.set(idle: false, type: navigator.category.type, sort: sort)

            searchQuery = ""
            searchResults = nil
            searchFields = SearchFields.defaultFields(for: navigator.category.type)

            scrollToCurrentMedia()
            try? await Task.sleep(for: .milliseconds(200))
            scrollToCurrentMedia()
        }
        .task(id: sort) {
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
            ForEach(SearchFields.availableFields(for: mpd.database.type), id: \.self) { field in
                Toggle(isOn: Binding(
                    get: { searchFields.contains(field) },
                    set: { _ in searchFields.toggle(field) },
                )) {
                    Label {
                        switch field {
                        case .title:
                            Text("Title")
                        case .artist:
                            Text("Artist")
                        case .album:
                            Text("Album")
                        case .genre:
                            Text("Genre")
                        }
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
            ForEach(navigator.category.type.availableSortOptions, id: \.self) { option in
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
        } label: {
            Image(systemSymbol: .line3HorizontalDecrease)
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

    @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabledSetting = false
    @AppStorage(Setting.intelligenceModel) private var intelligenceModel = IntelligenceModel.openAI

    var isIntelligenceEnabled: Bool {
        guard isIntelligenceEnabledSetting else { return false }
        @AppStorage(intelligenceModel.setting) var token = ""
        return !token.isEmpty
    }

    let playlist: Playlist

    @State private var songs: [Song]?
    @State private var scrollTarget: ScrollTarget?
    @State private var showIntelligencePlaylistSheet = false
    @State private var playlistToEdit: Playlist?
    @State private var showReplaceQueueAlert = false

    private let fillIntelligencePlaylistNotification = NotificationCenter.default
        .publisher(for: .fillIntelligencePlaylistNotification)

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
                .mediaListStyle(rowHeight: Layout.RowHeight.song + Layout.Padding.large)
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
                    .disabled(!isIntelligenceEnabled)
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
        .sheet(isPresented: $showIntelligencePlaylistSheet) {
            IntelligenceView(target: .playlist($playlistToEdit), showSheet: $showIntelligencePlaylistSheet)
        }
        .alert("Replace Queue", isPresented: $showReplaceQueueAlert) {
            Button("Cancel", role: .cancel) {}

            AsyncButton("Replace", role: .destructive) {
                try await ConnectionManager.command().loadPlaylist(playlist)
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

        do {
            try await ConnectionManager.command().move(song, to: destination, in: navigator.category.source)
            self.songs = try await mpd.playlists.getSongs(for: playlist)
        } catch {
            print("Failed to reorder song in playlist: \(error)")
        }
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
