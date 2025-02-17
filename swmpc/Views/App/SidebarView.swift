//
//  SidebarView.swift
//  swmpc
//
//  Created by Camille Scholtz on 01/31/2025.
//

import SwiftUI

struct SidebarView: View {
    @Environment(MPD.self) private var mpd

    @Binding var selected: Category
    @Binding var queue: [any Mediable]?
    @Binding var query: String

    @State private var isEditingPlaylist = false
    @State private var playlistName = ""

    @State private var playlistToDelete: Playlist?

    @FocusState private var isFocused: Bool

    var body: some View {
        List(selection: $selected) {
            Text("swmpc")
                .font(.system(size: 18))
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .padding(.bottom, 15)

            ForEach(categories) { category in
                NavigationLink(value: category) {
                    Label(category.label, systemImage: category.image)
                }
            }

            Section("Playlists") {
                NavigationLink(value: Category(type: .playlist, playlist: Playlist(id: 0, position: 0, name: "Favorites"), label: "Favorites", image: "heart")) {
                    Label("Favorites", systemImage: "heart")
                }

                ForEach(mpd.queue.playlists ?? []) { playlist in
                    let category = Category(type: .playlist, playlist: playlist, label: playlist.name, image: "music.note.list")

                    NavigationLink(value: category) {
                        Label(category.label, systemImage: category.image)
                    }
                    .contextMenu {
                        Button("Delete Playlist") {
                            Task {
                                playlistToDelete = playlist
                            }
                        }
                    }
                }

                if isEditingPlaylist {
                    TextField("Untitled Playlist", text: $playlistName)
                        .focused($isFocused)
                        .onSubmit {
                            Task {
                                try? await ConnectionManager.command().createPlaylist(named: playlistName)

                                isEditingPlaylist = false
                                playlistName = ""
                                isFocused = false
                            }
                        }
                }

                Label("New Playlist", systemImage: "plus")
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

                    Task {
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
        .task(id: selected) {
            try? await mpd.queue.set(for: selected.type)

            if selected.type == .playlist {
                guard let playlist = selected.playlist else {
                    return
                }

                queue = try? await ConnectionManager.command().getPlaylist(playlist)
            } else {
                queue = mpd.queue.media
            }

            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: selected.type, using: song)
        }
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: selected.type, using: song)
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
