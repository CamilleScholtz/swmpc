//
//  AlbumsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct AlbumsView: View {
    @Environment(MPD.self) private var mpd

    @AppStorage(Setting.scrollToCurrent) private var scrollToCurrent = false

    private var albums: [Album] {
        mpd.queue.media as? [Album] ?? []
    }

    var body: some View {
        ForEach(albums) { album in
            AlbumView(for: album)
        }
        .onChange(of: mpd.status.media as? Album) { previous, _ in
            if scrollToCurrent {
                NotificationCenter.default.post(name: .scrollToCurrentNotification, object: previous != nil)
            } else {
                guard previous == nil else {
                    return
                }

                NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
            }
        }
        .task(id: mpd.status.song, priority: .medium) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: song, using: .album)
        }
    }
}
