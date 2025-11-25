//
//  PlaylistsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/04/2025.
//

import ButtonKit
import SwiftUI

struct PlaylistsView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    @State private var showDeleteAlert = false
    @State private var playlistToDelete: Playlist?

    @State private var isRenamingPlaylist = false
    @State private var playlistToRename: Playlist?

    @State private var isCreatingPlaylist = false
    @State private var playlistName = ""

    @FocusState private var isFocused: Bool

    private var playlists: [Playlist] {
        [Playlist(name: "Favorites")] + (mpd.playlists.playlists ?? [])
    }

    var body: some View {
        List {
            ForEach(playlists) { playlist in
                if isRenamingPlaylist, playlist == playlistToRename {
                    TextField(playlistName, text: $playlistName)
                        .focused($isFocused)
                        .onChange(of: isFocused) { _, value in
                            guard !value else {
                                return
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isRenamingPlaylist = false
                                playlistToRename = nil
                                playlistName = ""
                            }
                        }
                        .onSubmit {
                            Task(priority: .userInitiated) {
                                try await ConnectionManager.command {
                                    try await $0.renamePlaylist(playlist, to: playlistName)
                                }

                                isRenamingPlaylist = false
                                playlistToRename = nil
                                playlistName = ""
                            }
                        }
                        .mediaRowStyle()
                } else {
                    Button {
                        navigator.path.append(ContentDestination.playlist(playlist))
                    } label: {
                        Label(playlist.name, systemSymbol: playlist.name == "Favorites" ? .heart : .musicNoteList)
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if playlist.name != "Favorites" {
                            Button("Rename Playlist", systemSymbol: .pencil) {
                                isRenamingPlaylist = true
                                playlistName = playlist.name
                                playlistToRename = playlist
                                isFocused = true
                            }

                            Button("Delete Playlist", systemSymbol: .trash, role: .destructive) {
                                playlistToDelete = playlist
                                showDeleteAlert = true
                            }
                        }
                    }
                    .mediaRowStyle()
                }
            }

        }
        .mediaListStyle()
        .task {
            mpd.state.isLoading = true

            try? await Task.sleep(for: .milliseconds(200))
            mpd.state.isLoading = false
        }
        .alert("Delete Playlist", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                playlistToDelete = nil
                showDeleteAlert = false
            }

            AsyncButton("Delete", role: .destructive) {
                guard let playlist = playlistToDelete else {
                    throw ViewError.missingData
                }

                try await ConnectionManager.command {
                    try await $0.removePlaylist(playlist)
                }

                playlistToDelete = nil
                showDeleteAlert = false
            }
        } message: {
            if let playlist = playlistToDelete {
                Text("Are you sure you want to delete playlist '\(playlist.name)'?")
            }
        }
        .toolbar {
            ToolbarItem {
                Button("New Playlist", systemSymbol: .plus) {
                    playlistName = ""
                    isCreatingPlaylist = true
                }
            }
            
            ToolbarSpacer()

            ToolbarItem {
                Menu {
                    Button {
                        navigator.showSettings()
                    } label: {
                        Label("Settings", systemSymbol: .gearshape)
                    }
                } label: {
                    Image(systemSymbol: .ellipsis)
                }
            }
        }
        .alert("New Playlist", isPresented: $isCreatingPlaylist) {
            TextField("Playlist Name", text: $playlistName)

            Button("Cancel", role: .cancel) {
                playlistName = ""
            }

            AsyncButton("Create", role: .confirm) {
                guard !playlistName.isEmpty else {
                    return
                }

                try await ConnectionManager.command {
                    try await $0.createPlaylist(named: playlistName)
                }

                playlistName = ""
            }
        }
    }
}
