//
//  ArtistsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct ArtistsView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator

    @AppStorage(Setting.scrollToCurrent) private var scrollToCurrent = false

    private var artists: [Artist] {
        mpd.queue.media as? [Artist] ?? []
    }

    var body: some View {
        ForEach(artists) { artist in
            ArtistView(for: artist)
        }
        .onAppear {
            NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
        }
        .onChange(of: mpd.status.media as? Artist) { previous, _ in
            if scrollToCurrent {
                NotificationCenter.default.post(name: .scrollToCurrentNotification, object: previous != nil)
            } else {
                guard previous == nil else {
                    return
                }

                NotificationCenter.default.post(name: .scrollToCurrentNotification, object: false)
            }
        }
        .task(id: mpd.status.song, priority: .high) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: song, using: .artist)
        }
    }
}
