//
//  MediaListView.swift
//  swmpc
//
//  Created by Camille Scholtz on 21/06/2025.
//

import SwiftUI

struct MediaListView: View {
    @Environment(MPD.self) private var mpd

    @State private var library: LibraryManager

    private let type: MediaType

    private let startSearchingNotification = NotificationCenter.default
        .publisher(for: .startSearchingNotication)

    init(using library: LibraryManager, type: MediaType) {
        _library = State(initialValue: library)
        self.type = type
    }

    init(for playlist: Playlist) {
        _library = State(initialValue: LibraryManager(using: .playlist(playlist)))
        type = .song
    }

    var body: some View {
        Group {
            switch type {
            case .song:
                ForEach(library.media.compactMap { $0 as? Song }) { song in
                    SongView(for: song)
                }
            case .album:
                ForEach(library.media.compactMap { $0 as? Album }) { album in
                    AlbumView(for: album)
                }
            case .artist:
                ForEach(library.media.compactMap { $0 as? Artist }) { artist in
                    ArtistView(for: artist)
                }
            default:
                EmptyView()
            }

            // XXX: Kinda hacky, but required because else the tasks below never fire.
            if library.media.isEmpty {
                Color.clear
                    .frame(height: 0)
            }
        }
        .listRowSeparator(.hidden)
        #if os(iOS)
            .listRowInsets(.init(top: 7.5, leading: 15, bottom: 7.5, trailing: 15))
        #elseif os(macOS)
            .listRowInsets(.init(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5))
        #endif
            .task(id: library.source) {
                guard type != .playlist else {
                    return
                }

                try? await library.set(using: type)
            }
            .onReceive(startSearchingNotification) { notification in
                guard let query = notification.object as? String else {
                    return
                }

                Task {
                    if query.isEmpty {
                        library.clearResults()
                    } else {
                        try? await library.search(for: query, using: type)
                    }
                }
            }
    }
}
