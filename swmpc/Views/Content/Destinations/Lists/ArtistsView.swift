//
//  ArtistsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct ArtistsView: View {
    @Environment(MPD.self) private var mpd

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
        // Don't update media on song change - this breaks navigation
    }
}
