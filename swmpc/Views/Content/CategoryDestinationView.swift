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

    @AppStorage(Setting.albumSortOption) private var albumSort = SortDescriptor(option: .artist)
    @AppStorage(Setting.artistSortOption) private var artistSort = SortDescriptor(option: .artist)
    @AppStorage(Setting.songSortOption) private var songSort = SortDescriptor(option: .album)

    @State private var scrollProxy: ScrollViewProxy?

    @State private var searchQuery = ""
    @State private var isSearchFieldExpanded = false

    @FocusState private var isSearchFieldFocused: Bool

    private let scrollToCurrentNotification = NotificationCenter.default
        .publisher(for: .scrollToCurrentNotification)

    #if os(macOS)
        private var rowHeight: CGFloat {
            switch destination {
            case .albums, .artists: 65
            case .songs, .playlist: 46.5
            }
        }
    #endif

    private var currentSort: SortDescriptor {
        switch destination {
        case .albums: albumSort
        case .artists: artistSort
        case .songs: songSort
        default: SortDescriptor(option: .artist)
        }
    }

    private var availableSortOptions: [SortOption] {
        destination.type.availableSortOptions
    }

    var body: some View {
        ListView(rowHeight: rowHeight) { proxy in
            Group {
                if case let .playlist(playlist) = destination {
                    MediaView(using: playlist, searchQuery: searchQuery)
                } else {
                    MediaView(using: mpd.database, searchQuery: searchQuery)
                }
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
        .id("\(destination)_\(currentSort.rawValue)")
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
                Menu {
                    ForEach(SearchManager.SearchField.allCases) { field in
                        Button {
                            mpd.search.toggle(field)
                        } label: {
                            HStack {
                                if mpd.search.enabledFields.contains(field) {
                                    Image(systemSymbol: .checkmark)
                                }
                                field.systemImage
                                Text(field.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemSymbol: .sliderHorizontal3)
                }
                .menuIndicator(.hidden)
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
                    ForEach(availableSortOptions, id: \.self) { option in
                        Button {
                            let newSort = if currentSort.option == option {
                                SortDescriptor(option: option, direction: currentSort.direction == .ascending ? .descending : .ascending)
                            } else {
                                SortDescriptor(option: option)
                            }

                            switch destination {
                            case .albums: albumSort = newSort
                            case .artists: artistSort = newSort
                            case .songs: songSort = newSort
                            default: break
                            }
                        } label: {
                            if currentSort.option == option {
                                Image(systemSymbol: .checkmark)
                            }

                            Text(option.label)

                            if currentSort.option == option {
                                Text(currentSort.direction.label)
                            }
                        }
                    }
                } label: {
                    Image(systemSymbol: .line3HorizontalDecrease)
                }
                .menuIndicator(.hidden)
            }
            .hidden(isSearchFieldExpanded || !destination.source.isSortable)

            ToolbarItem {
                Button {
                    isSearchFieldExpanded.toggle()
                    isSearchFieldFocused = isSearchFieldExpanded
                    if !isSearchFieldExpanded {
                        searchQuery = ""
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

            switch value {
            case .albums:
                mpd.database.type = .album
            case .artists:
                mpd.database.type = .artist
            case .songs:
                mpd.database.type = .song
            default:
                break
            }

            // TODO: Does not work!
//            Task {
//                while true {
//                    try? await Task.sleep(for: .seconds(0.1))
//
//                    if mpd.database.media != nil {
//                        NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
//                        break
//                    }
//                }
//            }
        }
        .onChange(of: currentSort) { _, value in
            mpd.state.isLoading = true
            mpd.database.sort = value
            
            NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
        }
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
