//
//  SongsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct SongsView: View {
    @Environment(MPD.self) private var mpd

    @AppStorage(Setting.scrollToCurrent) private var scrollToCurrent = false

    private var songs: [Song] {
        mpd.queue.media as? [Song] ?? []
    }

    var body: some View {
        ForEach(songs) { song in
            SongView(for: song)
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
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: song, using: .song)
        }
    }
}
