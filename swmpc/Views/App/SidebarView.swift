//
//  SidebarView.swift
//  swmpc
//
//  Created by Camille Scholtz on 01/31/2025.
//

import SwiftUI

struct SidebarView: View {
    @Environment(MPD.self) private var mpd
    @Environment(Router.self) private var router

    @State private var showQueueAlert = false
    @State private var playlistToQueue: Playlist?

    @State private var showDeleteAlert = false
    @State private var playlistToDelete: Playlist?

    @State private var isEditingPlaylist = false
    @State private var playlistName = ""

    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var boundRouter = router

        List(selection: $boundRouter.category) {
            Text("swmpc")
                .font(.system(size: 18))
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .padding(.bottom, 15)

            ForEach(router.categories) { category in
                NavigationLink(value: category) {
                    Label(category.label, systemSymbol: category.image)
                }
            }

            Section("Playlists") {
                ForEach(router.playlists) { category in
                    NavigationLink(value: category) {
                        Label(category.label, systemSymbol: category.image)
                    }
                    .contextMenu {
                        if category.label != "Favorites" {
                            Button("Delete Playlist") {
                                Task(priority: .userInitiated) {
                                    playlistToDelete = category.playlist
                                    showDeleteAlert = true
                                }
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
        }
        .toolbar(removing: .sidebarToggle)
        .task(id: mpd.queue.playlists) {
            guard let playlists = mpd.queue.playlists else {
                return
            }

            router.setPlaylists(playlists)
        }
        .task(id: mpd.status.playlist) {
            // TODO: Figure this out.
            guard let playlist = mpd.status.playlist else {
                // category = categories.first!
                return
            }

            guard let category = router.playlists.first(where: { $0.playlist?.name == playlist.name }) else {
                return
            }

            router.category = category
        }
        .task(id: router.category) {
            if router.category.playlist == mpd.status.playlist {
                try? await mpd.queue.set(using: router.category.type)
            } else {
                playlistToQueue = router.category.playlist
                showQueueAlert = true
            }
        }
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: song, using: router.category.type)
        }
        .alert("Queue Playlist", isPresented: $showQueueAlert) {
            Button("Queue") {
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().loadPlaylist(playlistToQueue)
                    try? await mpd.queue.set(using: router.category.type)

                    playlistToQueue = nil
                    showQueueAlert = false
                }
            }

            Button("Cancel", role: .cancel) {
                playlistToQueue = nil
                showQueueAlert = false

                router.category = router.previousCategory
            }
        } message: {
            if let playlist = playlistToQueue {
                Text("Are you sure you want to queue playlist ’\(playlist.name)’?")
            } else {
                Text("Are you sure you want to queue the library?")
            }
        }
        .alert("Delete Playlist", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                guard let playlist = playlistToDelete else {
                    return
                }

                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().removePlaylist(playlist)

                    playlistToDelete = nil
                    showDeleteAlert = false
                }
            }

            Button("Cancel", role: .cancel) {
                playlistToDelete = nil
                showDeleteAlert = false
            }
        } message: {
            if let playlist = playlistToDelete {
                Text("Are you sure you want to delete playlist ’\(playlist.name)’?")
            }
        }
    }
}
