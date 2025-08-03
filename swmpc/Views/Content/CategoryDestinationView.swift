//
//  CategoryDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
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

    @State private var scrollProxy: ScrollViewProxy?
    @State private var currentCategoryID = UUID()

    // @State private var enabledSearchFields: Set<SearchField> = [.title, .artist, .album]
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

    // TODO: Get actual heights.
    private var rowHeight: CGFloat {
        switch navigator.category {
        case .albums, .artists: 65 + 15
        default: 31.5 + 15
        }
    }

    var body: some View {
        Group {
            if let media = mpd.database.media, !media.isEmpty {
                 ListView(rowHeight: rowHeight) { proxy in
                     ForEach(media, id: \.id) { row in
                         RowView(media: row)
                     }
                     .onAppear {
                         scrollProxy = proxy

                         if let currentSong = mpd.status.song {
                             let request = ScrollManager.ScrollRequest(destination: .currentMedia, animate: false)
                             NotificationCenter.default.post(name: .performScrollNotification, object: request)
                         }
                     }
                 }
                 .id(navigator.category)
            } else {
                EmptyCategoryView(destination: navigator.category)
            }
        }
        .toolbar {
            ToolbarItem {
                TextField("Search", text: $searchQuery)
                    .frame(width: 195)
                    .autocorrectionDisabled()
            }
            .hidden(!isSearchFieldExpanded)

            ToolbarItem {
                Menu {
                    //                     ForEach(SearchField.allCases) { field in
                    //                         Button {
                    //                             if enabledSearchFields.contains(field) {
                    //                                 enabledSearchFields.remove(field)
                    //                             } else {
                    //                                 enabledSearchFields.insert(field)
                    //                             }
                    //                         } label: {
                    //                             HStack {
                    //                                 if enabledSearchFields.contains(field) {
                    //                                     Image(systemSymbol: .checkmark)
                    //                                 }
                    //                                 field.systemImage
                    //                                 Text(field.rawValue)
                    //                             }
                    //                         }
                    //                     }
                } label: {
                    Image(systemSymbol: .sliderHorizontal3)
                }
                .menuIndicator(.hidden)
            }
            .hidden(!isSearchFieldExpanded)

            ToolbarItem {
                Button {
                    if let currentSong = mpd.status.song {
                        let request = ScrollManager.ScrollRequest(destination: .currentMedia, animate: true)
                        NotificationCenter.default.post(name: .performScrollNotification, object: request)
                    }
                } label: {
                    Image(systemSymbol: .dotViewfinder)
                }
                .disabled(mpd.status.song == nil)
            }
            .hidden(isSearchFieldExpanded)

            ToolbarSpacer(.fixed)

            ToolbarItem {
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
            .hidden(isSearchFieldExpanded || !navigator.category.source.isSortable)

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
        .onChange(of: navigator.category) { _, value in
            mpd.state.isLoading = true

            Task(priority: .userInitiated) {
                try? await mpd.database.set(idle: false, type: value.type)

                if let currentSong = mpd.status.song {
                    let request = ScrollManager.ScrollRequest(destination: .currentMedia, animate: false)
                    NotificationCenter.default.post(name: .performScrollNotification, object: request)
                }
            }
        }
        .onChange(of: sort) { _, value in
            mpd.state.isLoading = true

            Task(priority: .userInitiated) {
                try? await mpd.database.set(idle: false, sort: value)

                if let currentSong = mpd.status.song {
                    let request = ScrollManager.ScrollRequest(destination: .currentMedia, animate: false)
                    NotificationCenter.default.post(name: .performScrollNotification, object: request)
                }
            }
        }
    }
}

struct CategoryPlaylistView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    let playlist: Playlist

    @State private var scrollProxy: ScrollViewProxy?

    @State private var media: [Song]?

    // TODO: Get actual heights.
    private let rowHeight: CGFloat = 31.5 + 15

    var body: some View {
        Group {
            if let media, !media.isEmpty {
                ListView(rowHeight: rowHeight) { proxy in
                    ForEach(media, id: \.id) { row in
                        RowView(media: row)
                    }
                    .onMove(perform: { source, destination in
                        Task {
                            guard let index = source.first,
                                  index >= 0,
                                  index < media.count,
                                  destination >= 0,
                                  destination <= media.count
                            else {
                                return
                            }

                            let adjustedTo = index < destination ? destination - 1 : destination
                            try? await ConnectionManager.command().move(media[index], to: adjustedTo, in: navigator.category.source)

                            if case .playlist = navigator.category.source {
                                NotificationCenter.default.post(name: .playlistModifiedNotification, object: nil)
                            } else if case .favorites = navigator.category.source {
                                NotificationCenter.default.post(name: .playlistModifiedNotification, object: nil)
                            }
                        }
                    })
                    .onAppear {
                        scrollProxy = proxy

                        if let currentSong = mpd.status.song {
                            let request = ScrollManager.ScrollRequest(destination: .currentMedia, animate: false)
                            NotificationCenter.default.post(name: .performScrollNotification, object: request)
                        }
                    }
                }
                .id(playlist)
            } else {
                EmptyCategoryView(destination: navigator.category)
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    if let currentSong = mpd.status.song {
                        let request = ScrollManager.ScrollRequest(destination: .currentMedia, animate: true)
                        NotificationCenter.default.post(name: .performScrollNotification, object: request)
                    }
                } label: {
                    Image(systemSymbol: .dotViewfinder)
                }
                .disabled(mpd.status.song == nil)
            }

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

            media = try? await mpd.playlists.getSongs(for: playlist)

            if let currentSong = mpd.status.song {
                let request = ScrollManager.ScrollRequest(destination: .currentMedia, animate: false)
                NotificationCenter.default.post(name: .performScrollNotification, object: request)
            }
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

// struct CategoryDestinationView: View {

//     enum SearchField: String, CaseIterable, Identifiable {
//         case title = "Title"
//         case artist = "Artist"
//         case album = "Album"

//         var id: String { rawValue }

//         var systemImage: Image {
//             switch self {
//             case .title: Image(systemSymbol: .musicNote)
//             case .artist: Image(systemSymbol: .person)
//             case .album: Image(systemSymbol: .squareStack)
//             }
//         }
//     }

//         .onReceive(performScrollNotification) { notification in
//             guard let request = notification.object as? ScrollManager.ScrollRequest else { return }

//             Task {
//                 switch request.destination {
//                 case .currentMedia:
//                     try? await scrollToCurrent(animate: request.animate)
//                 case let .specificItem(id):
//                     scrollProxy?.scrollTo(id, anchor: .center)
//                 }
//             }
//         }
//         .onReceive(playlistModifiedNotification) { _ in
//             Task {
//                 await refreshPlaylistSongs()
//             }
//         }
//         .task(id: searchQuery, priority: .high) {
//             await performSearch(query: searchQuery)
//         }
//     }

//     private func performSearch(query: String) async {
//         guard !query.isEmpty, navigator.category.source == .database else {
//             searchResults = nil
//             return
//         }

//         searchResults = []

//         let mpdFields = enabledSearchFields.compactMap { field -> String in
//             switch field {
//             case .title: return "title"
//             case .artist: return "artist"
//             case .album: return "album"
//             }
//         }

//         searchResults = await mpd.database.search(
//             query: query,
//             fields: Set(mpdFields),
//         )
//     }

//     private func refreshPlaylistSongs() async {
//         if case let .playlist(playlist) = navigator.category.source {
//             if playlist.name == "Favorites" {
//                 try? await mpd.playlists.set()
//             } else {
//                 loadedPlaylistSongs = await (try? mpd.playlists.getSongs(for: playlist)) ?? []
//             }
//         }
//     }
// }
