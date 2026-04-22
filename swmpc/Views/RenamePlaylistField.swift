//
//  RenamePlaylistField.swift
//  swmpc
//
//  Created by Camille Scholtz on 23/04/2026.
//

import MPDKit
import SwiftUI

struct RenamePlaylistField: View {
    let playlist: Playlist
    @Binding var isRenamingPlaylist: Bool
    @Binding var playlistToRename: Playlist?
    @Binding var playlistName: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField(playlistName, text: $playlistName)
            .focused(isFocused)
            .onChange(of: isFocused.wrappedValue) { _, value in
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
    }
}
