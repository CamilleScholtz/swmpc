//
//  SidebarView.swift
//  swmpc
//
//  Created by Camille Scholtz on 01/31/2025.
//

import SwiftUI

struct SidebarView: View {
    @Environment(MPD.self) private var mpd

    @Binding var destination: SidebarDestination

    @State private var showDeleteAlert = false
    @State private var playlistToDelete: Playlist?

    @State private var isRenamingPlaylist = false
    @State private var playlistToRename: Playlist?

    @State private var isCreatingPlaylist = false
    @State private var playlistName = ""

    @FocusState private var isFocused: Bool

    var body: some View {
        List(selection: $destination) {
            Text("swmpc")
                .font(.system(size: 18))
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .padding(.bottom, 15)

            ForEach(SidebarDestination.categories) { category in
                NavigationLink(value: category) {
                    Label(category.label, systemSymbol: category.symbol)
                }
            }

            Section("Playlists") {
                if let playlists = mpd.queue.playlists {
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
                            NavigationLink(value: SidebarDestination.playlist(playlist)) {
                                Label(playlist.name, systemSymbol: .musicNoteList)
                            }
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
        }
        .toolbar(removing: .sidebarToggle)
        .handleQueueChange(destination: $destination)
        .alert("Delete Playlist", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {
                playlistToDelete = nil
                showDeleteAlert = false
            }

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
        } message: {
            if let playlist = playlistToDelete {
                Text("Are you sure you want to delete playlist ’\(playlist.name)’?")
            }
        }
    }
}
