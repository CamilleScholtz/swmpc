//
//  PlaylistsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/04/2025.
//

import SwiftUI

struct PlaylistsView: View {
    @Environment(MPD.self) private var mpd

    var body: some View {
        let playlists = [Playlist(name: "Favorites")] + (mpd.queue.playlists ?? [])
        
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(playlists) { playlist in
                    HStack(spacing: 15) {
                        Label(playlist.name, systemSymbol: playlist.name == "Favorites" ? .heart : .musicNoteList)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
            }
        }
    }
}
