//
//  SidebarView.swift
//  swmpc
//
//  Created by Camille Scholtz on 01/31/2025.
//

import ButtonKit
import SwiftUI

struct SidebarView: View {
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
        [Playlist(name: "Favorites")] + (mpd.queue.playlists ?? [])
    }

    var body: some View {
        @Bindable var boundNavigator = navigator

        List(selection: $boundNavigator.category) {
            Text("swmpc")
                .font(.system(size: 18))
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .padding(.bottom, 15)

            ForEach(CategoryDestination.categories) { category in
                NavigationLink(value: category) {
                    Label(category.label, systemSymbol: category.symbol)
                }
                .keyboardShortcut(category.shortcut ?? .none)
            }

            Section("Playlists") {
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
                                    try await ConnectionManager.command().renamePlaylist(playlist, to: playlistName)

                                    isRenamingPlaylist = false
                                    playlistToRename = nil
                                    playlistName = ""
                                }
                            }
                    } else {
                        NavigationLink(value: CategoryDestination.playlist(playlist)) {
                            Label(playlist.name, systemSymbol: playlist.name == "Favorites" ? .heart : .musicNoteList)
                        }
                        .keyboardShortcut(.none)
                        .help(Text(playlist.name))
                        .contextMenu {
                            if playlist.name != "Favorites" {
                                Button("Rename Playlist") {
                                    isRenamingPlaylist = true
                                    playlistName = playlist.name
                                    playlistToRename = playlist
                                    isFocused = true
                                }

                                Button("Delete Playlist") {
                                    playlistToDelete = playlist
                                    showDeleteAlert = true
                                }
                            }
                        }
                    }
                }

                if isCreatingPlaylist {
                    TextField("Untitled Playlist", text: $playlistName)
                        .focused($isFocused)
                        .onChange(of: isFocused) { _, value in
                            guard !value else {
                                return
                            }

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                isCreatingPlaylist = false
                                playlistName = ""
                            }
                        }
                        .onSubmit {
                            Task(priority: .userInitiated) {
                                try? await ConnectionManager.command().createPlaylist(named: playlistName)

                                isCreatingPlaylist = false
                                playlistName = ""
                            }
                        }
                }

                // TODO: This button doesn't take up the full width.
                Button(action: {
                    isCreatingPlaylist = true
                    isFocused = true
                }) {
                    Label("New Playlist", systemSymbol: .plus)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .toolbar(removing: .sidebarToggle)
        .handleQueueChange()
        .alert("Delete Playlist", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                playlistToDelete = nil
                showDeleteAlert = false
            }

            AsyncButton("Delete", role: .destructive) {
                guard let playlist = playlistToDelete else {
                    throw ViewError.missingData
                }

                try await ConnectionManager.command().removePlaylist(playlist)

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
