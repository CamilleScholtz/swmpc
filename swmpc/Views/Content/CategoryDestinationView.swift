//
//  CategoryDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

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

    @AppStorage(Setting.albumSortOption) private var albumSortOptionRaw = ""
    @AppStorage(Setting.artistSortOption) private var artistSortOptionRaw = ""
    @AppStorage(Setting.songSortOption) private var songSortOptionRaw = ""

    private var albumSortOption: SortOption {
        SortOption(rawValue: albumSortOptionRaw) ?? MediaType.album.defaultSortOption
    }

    private var artistSortOption: SortOption {
        SortOption(rawValue: artistSortOptionRaw) ?? MediaType.artist.defaultSortOption
    }

    private var songSortOption: SortOption {
        SortOption(rawValue: songSortOptionRaw) ?? MediaType.song.defaultSortOption
    }

    #if os(macOS)
        private var rowHeight: CGFloat {
            switch destination {
            case .albums, .artists: 65
            case .songs, .playlist: 46.5
            }
        }
    #endif

    @State private var offset: CGFloat = 0

    @State private var isSearching = false
    @State private var searchQuery = ""
    @State private var isSearchFieldExpanded = false

    @FocusState private var isSearchFieldFocused: Bool

    #if os(iOS)
        @State private var showSearchButton = false
        @State private var isGoingToSearch = false
    #endif

    private let startSearchingNotication = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    private let scrollToCurrentNotification = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)

    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        ListView(rowHeight: rowHeight) { proxy in
            Group {
                if case let .playlist(playlist) = destination {
                    MediaView(using: playlist, searchQuery: searchQuery)
                } else {
                    let sortOption: SortOption = switch destination {
                    case .albums:
                        albumSortOption
                    case .artists:
                        artistSortOption
                    case .songs:
                        songSortOption
                    default:
                        mpd.database.type.defaultSortOption
                    }
                    MediaView(using: mpd.database, searchQuery: searchQuery, sortOption: sortOption)
                }
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
        .id(destination)
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
        .toolbar(removing: .title)
        .toolbar {
            // TODO: I want to use DefaultToolbarItem, but that seems to be broken.
            // See: https://github.com/feedback-assistant/reports/issues/696
            ToolbarItem {
                Text(destination.label)
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                    .padding(.leading, 12)
            }
            .sharedBackgroundVisibility(.hidden)
            .hidden(isSearchFieldExpanded)

            ToolbarSpacer(.flexible)
                .hidden(isSearchFieldExpanded)

            ToolbarItem {
                TextField("Search", text: $searchQuery)
                    .frame(width: 244)
                    .autocorrectionDisabled()
            }
            .hidden(!isSearchFieldExpanded)

            ToolbarItem {
                Button {
                    NotificationCenter.default.post(name: .scrollToCurrentNotification, object: true)
                } label: {
                    Image(systemSymbol: .dotViewfinder)
                }
                .disabled(mpd.status.song == nil)
            }
            .hidden(isSearchFieldExpanded)

            ToolbarSpacer(.fixed)

            ToolbarItem {
                Menu {
                    switch destination {
                    case .albums:
                        ForEach(MediaType.album.availableSortFields, id: \.self) { field in
                            ForEach(SortDirection.allCases, id: \.self) { direction in
                                let option = SortOption(field: field, direction: direction)
                                Button {
                                    albumSortOptionRaw = option.rawValue
                                } label: {
                                    HStack {
                                        Text(option.label)
                                        if albumSortOption == option {
                                            Spacer()
                                            Image(systemSymbol: .checkmark)
                                        }
                                    }
                                }
                            }
                        }
                    case .artists:
                        ForEach(MediaType.artist.availableSortFields, id: \.self) { field in
                            ForEach(SortDirection.allCases, id: \.self) { direction in
                                let option = SortOption(field: field, direction: direction)
                                Button {
                                    artistSortOptionRaw = option.rawValue
                                } label: {
                                    HStack {
                                        Text(option.label)
                                        if artistSortOption == option {
                                            Spacer()
                                            Image(systemSymbol: .checkmark)
                                        }
                                    }
                                }
                            }
                        }
                    case .songs:
                        ForEach(MediaType.song.availableSortFields, id: \.self) { field in
                            ForEach(SortDirection.allCases, id: \.self) { direction in
                                let option = SortOption(field: field, direction: direction)
                                Button {
                                    songSortOptionRaw = option.rawValue
                                } label: {
                                    HStack {
                                        Text(option.label)
                                        if songSortOption == option {
                                            Spacer()
                                            Image(systemSymbol: .checkmark)
                                        }
                                    }
                                }
                            }
                        }
                    default:
                        EmptyView()
                    }
                } label: {
                    Image(systemSymbol: .line3HorizontalDecrease)
                }
                .disabled(destination == .playlist(Playlist(name: "")))
            }
            .hidden(isSearchFieldExpanded)

            ToolbarItem {
                Button {
                    withAnimation(.spring) {
                        isSearchFieldExpanded.toggle()
                        isSearching.toggle()
                        isSearchFieldFocused.toggle()
                    }
                } label: {
                    Image(systemSymbol: isSearchFieldExpanded ? .xmark : .magnifyingglass)
                }
            }
        }
        .onReceive(scrollToCurrentNotification) { notification in
            guard let scrollProxy else { return }
            Task {
                try? await scrollToCurrent(proxy: scrollProxy, animate: notification.object as? Bool ?? true)
            }
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
            #if os(iOS)
                default:
                    return;
            #endif
            }

            Task {
                while true {
                    try? await Task.sleep(for: .seconds(0.1))

                    if mpd.database.media != nil {
                        NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
                        break
                    }
                }
            }
        }
        .onChange(of: isSearching) { _, value in
            if value {
            } else {
                searchQuery = ""
                #if os(macOS)
                    isSearchFieldExpanded = false
                    isSearchFieldFocused = false
                #endif
            }
        }
        .onChange(of: searchQuery) { _, value in
            guard value.isEmpty else {
                return
            }

            NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
        }
//        .searchable(text: $query, isPresented: $isSearching)
//        .disableAutocorrection(true)
//        .onChange(of: isSearching) { _, value in
//            guard !value else {
//                return
//            }
//
//            if case .playlist = navigator.category {
//                NotificationCenter.default.post(name: .startSearchingNotication, object: "")
//            }
//        }
//        .onChange(of: isGoingToSearch) { _, value in
//            guard value else {
//                return
//            }
//
//            isSearching = true
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//                isGoingToSearch = false
//            }
//        }
//        .task(id: query) {
//            guard isSearching else {
//                return
//            }
//
//            // For playlists, search is handled by MediaListView internally
//            if case .playlist = navigator.category {
//                NotificationCenter.default.post(name: .startSearchingNotication, object: query.isEmpty ? "" : query)
//            }
//            // For database views, search will be handled by SwiftUI's searchable with filtered views
        // }
    }

    private func scrollToCurrent(proxy: ScrollViewProxy, animate: Bool = true) async throws {
        guard let song = mpd.status.song else {
            throw ViewError.missingData
        }

        var id: AnyHashable?
        switch destination {
        case .albums:
            guard let albums = mpd.database.media as? [Album] else {
                throw ViewError.missingData
            }
            id = albums.first(where: { $0 == song.album })?.id
        case .artists:
            guard let artists = mpd.database.media as? [Artist] else {
                throw ViewError.missingData
            }

            id = artists.first(where: { $0.name == song.artist })?.id
        case .songs:
            guard let songs = mpd.database.media as? [Song] else {
                throw ViewError.missingData
            }

            id = songs.first(where: { $0.url == song.url })?.id
        case .playlist:
            break
        #if os(iOS)
            default:
                throw ViewError.missingData
        #endif
        }

        guard let id else {
            throw ViewError.missingData
        }

        if animate {
            // TODO: Animations are very buggy at the moment.
            // withAnimation {
            proxy.scrollTo(id, anchor: .center)
            // }
        } else {
            proxy.scrollTo(id, anchor: .center)
        }
    }
}
