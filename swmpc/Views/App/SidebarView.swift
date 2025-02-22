//
//  SidebarView.swift
//  swmpc
//
//  Created by Camille Scholtz on 01/31/2025.
//

import SwiftUI

struct SidebarView: View {
    @Environment(MPD.self) private var mpd

    @Binding var category: Category
    @Binding var queue: [any Mediable]?
    @Binding var query: String

    @State private var isEditingPlaylist = false
    @State private var playlistName = ""

    @State private var playlistToDelete: Playlist?

    @FocusState private var isFocused: Bool

    var body: some View {
        List(selection: $category) {
            Text("swmpc")
                .font(.system(size: 18))
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .padding(.bottom, 15)

            let categories: [Category] = [
                .init(type: MediaType.album, playlist: nil, label: "Albums", image: .squareStack),
                .init(type: MediaType.artist, playlist: nil, label: "Artists", image: .musicMic),
                .init(type: MediaType.song, playlist: nil, label: "Songs", image: .musicNote),
            ]

            ForEach(categories) { category in
                NavigationLink(value: category) {
                    Label(category.label, systemSymbol: category.image)
                }
            }

            Section("Playlists") {
                NavigationLink(value: Category(type: .playlist, playlist: Playlist(id: 0, position: 0, name: "Favorites"), label: "Favorites", image: .heart)) {
                    Label("Favorites", systemSymbol: .heart)
                }

                ForEach(mpd.queue.playlists ?? []) { playlist in
                    let category = Category(type: .playlist, playlist: playlist, label: playlist.name, image: .musicNoteList)

                    NavigationLink(value: category) {
                        Label(category.label, systemSymbol: category.image)
                    }
                    .contextMenu {
                        Button("Delete Playlist") {
                            Task(priority: .userInitiated) {
                                playlistToDelete = playlist
                            }
                        }
                    }
                }

                if isEditingPlaylist {
                    TextField("Untitled Playlist", text: $playlistName)
                        .focused($isFocused)
                        .onSubmit {
                            Task(priority: .userInitiated) {
                                try? await ConnectionManager.command().createPlaylist(named: playlistName)

                                isEditingPlaylist = false
                                playlistName = ""
                                isFocused = false
                            }
                        }
                }

                Label("New Playlist", systemSymbol: .plus)
                    .onTapGesture(perform: {
                        isEditingPlaylist = true
                        isFocused = true
                    })
            }
            .alert("Delete Playlist", isPresented: .constant(playlistToDelete != nil)) {
                Button("Delete", role: .destructive) {
                    guard let playlist = playlistToDelete else {
                        return
                    }

                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().removePlaylist(playlist)
                        playlistToDelete = nil
                    }
                }
                .keyboardShortcut(.delete)

                Button("Cancel", role: .cancel) {
                    playlistToDelete = nil
                }
            } message: {
                if let playlist = playlistToDelete {
                    Text("Are you sure you want to delete '\(playlist.name)'?")
                }
            }
        }
        .navigationSplitViewColumnWidth(180)
        .toolbar(removing: .sidebarToggle)
        .task(id: category) {
            try? await mpd.queue.set(for: category.type)

            if category.type == .playlist {
                guard let playlist = category.playlist else {
                    return
                }

                queue = try? await ConnectionManager.command().getPlaylist(playlist)
            } else {
                queue = mpd.queue.media
            }

            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: category.type, using: song)
        }
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: category.type, using: song)
        }
        .onChange(of: query) { _, value in
            guard let type = mpd.queue.type else {
                return
            }

            guard !value.isEmpty else {
                queue = mpd.queue.media
                return
            }

            Task(priority: .userInitiated) {
                queue = try? await mpd.queue.search(for: value, using: type)
            }
        }
    }
}
