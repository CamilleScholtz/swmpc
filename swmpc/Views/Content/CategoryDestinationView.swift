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

    @State private var isSearchFieldExpanded = false

    var body: some View {
        Group {
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
#if os(macOS)
        .toolbar(removing: .title)
        .toolbar {
                ToolbarItem {
                    Text(navigator.category.label)
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .padding(.leading, 12)
                }
                .sharedBackgroundVisibility(.hidden)
                .hidden(isSearchFieldExpanded)

                ToolbarSpacer(.flexible)
                    .hidden(isSearchFieldExpanded)
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

    @State private var scrollTo: String?
    @State private var animatedScroll = false

    @State private var searchFields = SearchFields()
    @State private var searchQuery = ""
    @State private var searchResults: [any Mediable]?

    #if os(macOS)
    @FocusState private var isSearchFieldFocused: Bool
    #endif

    private var sort: SortDescriptor {
        switch navigator.category {
        case .albums: albumSort
        case .artists: artistSort
        case .songs: songSort
        default: SortDescriptor(option: .artist)
        }
    }

    @ViewBuilder
    private var searchResultsView: some View {
        switch mpd.database.type {
        case .album:
            if let albums = searchResults as? [Album] {
                CollectionView(data: albums, rowHeight: 65 + 15, contentMargin: EdgeInsets(top: 0, leading: 0, bottom: 7.5, trailing: 0), scrollTo: $scrollTo, animated: animatedScroll) {
                    RowView(media: $0)
                }
            }
        case .artist:
            if let artists = searchResults as? [Artist] {
                CollectionView(data: artists, rowHeight: 50 + 15, contentMargin: EdgeInsets(top: 0, leading: 0, bottom: 7.5, trailing: 0), scrollTo: $scrollTo, animated: animatedScroll) {
                    RowView(media: $0)
                }
            }
        default:
            if let songs = searchResults as? [Song] {
                CollectionView(data: songs, rowHeight: 31.5 + 15, contentMargin: EdgeInsets(top: 0, leading: 0, bottom: 7.5, trailing: 0), scrollTo: $scrollTo, animated: animatedScroll) {
                    RowView(media: $0)
                }
            }
        }
    }

    @ViewBuilder
    private var normalMediaView: some View {
        switch mpd.database.type {
        case .album:
            if let albums = mpd.database.media as? [Album] {
                CollectionView(data: albums, rowHeight: 65 + 15, contentMargin: EdgeInsets(top: 0, leading: 0, bottom: 7.5, trailing: 0), scrollTo: $scrollTo, animated: animatedScroll) {
                    RowView(media: $0)
                }
            }
        case .artist:
            if let artists = mpd.database.media as? [Artist] {
                CollectionView(data: artists, rowHeight: 50 + 15, contentMargin: EdgeInsets(top: 0, leading: 0, bottom: 7.5, trailing: 0), scrollTo: $scrollTo, animated: animatedScroll) {
                    RowView(media: $0)
                }
            }
        default:
            if let songs = mpd.database.media as? [Song] {
                CollectionView(data: songs, rowHeight: 31.5 + 15, contentMargin: EdgeInsets(top: 0, leading: 0, bottom: 7.5, trailing: 0), scrollTo: $scrollTo, animated: animatedScroll) {
                    RowView(media: $0)
                }
            }
        }
    }

    var body: some View {
        ZStack {
            if searchResults != nil {
                searchResultsView
                    .id(mpd.database.type)
                    .ignoresSafeArea(edges: .vertical)
            } else if let media = mpd.database.media, !media.isEmpty {
                normalMediaView
                    .id(mpd.database.type)
                    .ignoresSafeArea(edges: .vertical)
            } else {
                EmptyCategoryView(destination: navigator.category)
            }
        }
        #if os(iOS)
        .searchable(text: $searchQuery, placement: .navigationBarDrawer)
        .searchToolbarBehavior(.minimize)
        .toolbar {
            DefaultToolbarItem(kind: .title)
            
            ToolbarSpacer(.fixed)

            
            ToolbarItem {
                Button {
                    animatedScroll = true
                    scrollToCurrentMedia()
                } label: {
                    Image(systemSymbol: .dotViewfinder)
                }
                .disabled(mpd.status.song == nil)
            }

            ToolbarItem {
                if navigator.category.source.isSortable {
                    sortMenu
                }
            }
        }
        #else
        .toolbar {
            ToolbarItem {
                Group {
                    if isSearchFieldExpanded {
                        TextField("Search", text: $searchQuery)
                            .frame(width: 195)
                            .autocorrectionDisabled()
                            .focused($isSearchFieldFocused)
                    }
                }
            }

            ToolbarItem {
                Group {
                    if isSearchFieldExpanded {
                        searchFieldsMenu
                    }
                }
            }

            ToolbarItem {
                Group {
                    if !isSearchFieldExpanded {
                        Button {
                            animatedScroll = true
                            scrollToCurrentMedia()
                        } label: {
                            Image(systemSymbol: .dotViewfinder)
                        }
                        .disabled(mpd.status.song == nil)
                    }
                }
            }

            ToolbarSpacer(.fixed)

            ToolbarItem {
                Group {
                    if !isSearchFieldExpanded, navigator.category.source.isSortable {
                        sortMenu
                    }
                }
            }

            ToolbarItem {
                Button {
                    isSearchFieldExpanded.toggle()

                    if !isSearchFieldExpanded {
                        searchQuery = ""
                        searchResults = nil
                        #if os(macOS)
                        isSearchFieldFocused = false
                        #endif
                    } else {
                        // Delay focus to ensure TextField is rendered
                        #if os(macOS)
                        Task {
                            try? await Task.sleep(for: .milliseconds(50))
                            isSearchFieldFocused = true
                        }
                        #endif
                    }
                } label: {
                    Image(systemSymbol: isSearchFieldExpanded ? .xmark : .magnifyingglass)
                }
            }
        }
        #endif
        .task(id: navigator.category) {
            mpd.state.isLoading = true
            try? await mpd.database.set(idle: false, type: navigator.category.type, sort: sort)

            // Reset search when changing categories
            searchQuery = ""
            searchResults = nil

            // Set default search fields based on the new media type
            searchFields = SearchFields.defaultFields(for: navigator.category.type)

            scrollToCurrentMedia()
            try? await Task.sleep(for: .milliseconds(100))
            scrollToCurrentMedia()
        }
        .task(id: sort) {
            // Only reload if we're not already loading (category change handles both)
            guard !mpd.state.isLoading else { return }

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
                Button {
                    searchFields.toggle(field)
                } label: {
                    HStack {
                        if searchFields.contains(field) {
                            Image(systemSymbol: .checkmark)
                        }
                        Image(systemSymbol: field.symbol)
                        // Show appropriate label based on media type
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

    private func scrollToCurrentMedia() {
        guard let song = mpd.status.song else {
            return
        }

        switch navigator.category.type {
        case .album:
            scrollTo = song.album.id
        case .artist:
            scrollTo = song.album.artist.id
        default:
            scrollTo = song.id
        }
        
        // Reset animated flag after scrolling
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            animatedScroll = false
        }
    }
}

struct CategoryPlaylistView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    let playlist: Playlist

    @State private var songs: [Song]?
    @State private var scrollTo: String?

    var body: some View {
        Group {
            if let songs, !songs.isEmpty {
                CollectionView(data: songs, rowHeight: 31.5 + 15, contentMargin: EdgeInsets(top: 0, leading: 0, bottom: 7.5, trailing: 0), scrollTo: $scrollTo, animated: false) {
                    RowView(media: $0)
                }
                .id(playlist)
                .ignoresSafeArea(edges: .vertical)
            } else {
                EmptyCategoryView(destination: navigator.category)
            }
        }
        .toolbar {
            ToolbarSpacer(.fixed)

            ToolbarItem {
                AsyncButton {
                    try await ConnectionManager.command().loadPlaylist(playlist)
                } label: {
                    Image(systemSymbol: .square3Layers3d)
                }
            }
        }
        .task(id: playlist) {
            mpd.state.isLoading = true

            songs = try? await mpd.playlists.getSongs(for: playlist)
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
