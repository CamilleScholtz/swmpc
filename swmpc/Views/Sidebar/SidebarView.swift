//
//  SidebarView.swift
//  swmpc
//
//  Created by Camille Scholtz on 01/31/2025.
//

import ButtonKit
import MPDKit
import SFSafeSymbols
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
        if let existing = mpd.playlists.playlists, !existing.isEmpty {
            [Playlist(name: "Favorites")] + existing
        } else {
            [Playlist(name: "Favorites")]
        }
    }

    var body: some View {
        @Bindable var navigator = navigator

        List(selection: $navigator.category) {
            Text("swmpc")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
                .fontDesign(.rounded)
                .padding(.bottom, Layout.Padding.large)

            ForEach(CategoryDestination.categories) { category in
                NavigationLink(value: category) {
                    Label(String(localized: category.label), systemSymbol: category.symbol)
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

                                Task {
                                    try? await Task.sleep(for: .milliseconds(200))

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
                    } else {
                        NavigationLink(value: CategoryDestination.playlist(playlist)) {
                            Label(playlist.name, systemSymbol: playlist.name == "Favorites" ? .heart : .musicNoteList)
                        }
                        .keyboardShortcut(.none)
                        .help(Text(playlist.name))
                        .contextMenu {
                            if playlist.name != "Favorites" {
                                Button {
                                    isRenamingPlaylist = true
                                    playlistName = playlist.name
                                    playlistToRename = playlist
                                    isFocused = true
                                } label: {
                                    Label("Rename Playlist", systemSymbol: .pencil)
                                }

                                Button(role: .destructive) {
                                    playlistToDelete = playlist
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete Playlist", systemSymbol: .trash)
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

                            Task {
                                try? await Task.sleep(for: .milliseconds(200))
                                isCreatingPlaylist = false
                                playlistName = ""
                            }
                        }
                        .onSubmit {
                            Task(priority: .userInitiated) {
                                try? await ConnectionManager.command {
                                    try await $0.createPlaylist(named: playlistName)
                                }

                                isCreatingPlaylist = false
                                playlistName = ""
                            }
                        }
                }

                Button {
                    isCreatingPlaylist = true
                    isFocused = true
                } label: {
                    Label("New Playlist", systemSymbol: .plus)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
        .listStyle(.sidebar)
        .toolbar(removing: .sidebarToggle)
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
                Text("Are you sure you want to delete playlist ’\(playlist.name)’?")
            }
        }
    }
}
