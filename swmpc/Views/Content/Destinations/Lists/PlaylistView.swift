//
//  PlaylistView.swift
//  swmpc
//
//  Created by Camille Scholtz on 20/06/2025.
//

import SwiftUI

struct PlaylistView: View {
    @Environment(MPD.self) private var mpd

    @AppStorage(Setting.scrollToCurrent) private var scrollToCurrent = false

    let playlist: Playlist

    init(for playlist: Playlist) {
        self.playlist = playlist
    }

    @State private var songs: [Song] = []

    var body: some View {
        Group {
            ForEach(songs) { song in
                SongView(for: song)
            }

            if songs.isEmpty {
                Color.clear
                    .frame(height: 0)
            }
        }
        .onChange(of: mpd.status.media as? Song) { previous, _ in
            if scrollToCurrent {
                NotificationCenter.default.post(name: .scrollToCurrentNotification, object: previous != nil)
            } else {
                guard previous == nil else {
                    return
                }

                NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
            }
        }
        .task(id: playlist) {
            songs = await (try? ConnectionManager.command().getSongs(for: playlist)) ?? []
        }
        .task(id: mpd.status.song, priority: .medium) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.database.get(for: song, using: .song)
        }
    }
}
