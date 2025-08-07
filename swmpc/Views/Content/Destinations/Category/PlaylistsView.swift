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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(playlists) { playlist in
                    if isRenamingPlaylist, playlist == playlistToRename {
                        TextField(playlistName, text: $playlistName)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
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
                        Button {
                            navigator.category = CategoryDestination.playlist(playlist)
                        } label: {
                            HStack(spacing: 15) {
                                Label(playlist.name, systemSymbol: playlist.name == "Favorites" ? .heart : .musicNoteList)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
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

                                Button("Delete Playlist", systemSymbol: .trash) {
                                    playlistToDelete = playlist
                                    showDeleteAlert = true
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.clear)
                                .contentShape(Rectangle()),
                        )
                    }
                }

                if isCreatingPlaylist {
                    TextField("Untitled Playlist", text: $playlistName)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
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

                Button {
                    isCreatingPlaylist = true
                    isFocused = true
                } label: {
                    Label("New Playlist", systemSymbol: .plus)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                                .opacity(0.5),
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
        }
        .background(Color(.systemBackground))
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
