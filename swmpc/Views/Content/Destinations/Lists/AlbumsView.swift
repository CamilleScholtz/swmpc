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

    @State private var lastUpdated: Date = .now
    @State private var previousVisibleIndex = 0
    @State private var lastVisibleIndex = 0

    private var albums: [Album] {
        mpd.queue.media as? [Album] ?? []
    }

    var body: some View {
        ForEach(albums) { album in
            AlbumView(for: album)

                .onScrollVisibilityChange { isVisible in
                    guard isVisible else {
                        return
                    }

                    if let index = albums.firstIndex(of: album) {
                        let now = Date()

                        if now.timeIntervalSince(lastUpdated) > 0.01 {
                            lastVisibleIndex = index
                            lastUpdated = now
                        }
                    }
                }
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
        .task(id: lastVisibleIndex, priority: .medium) {
            guard !Task.isCancelled else {
                return
            }

            let currentPreviousIndex = previousVisibleIndex
            let currentLastIndex = lastVisibleIndex

            let isScrollingUp = currentLastIndex < currentPreviousIndex

            let albumsToPrefetch = {
                let start = isScrollingUp ? max(0, currentLastIndex - 2) : currentLastIndex + 1
                let end = isScrollingUp ? currentLastIndex : min(albums.count, currentLastIndex + 3)

                return Array(albums[start ..< end])
            }()

            previousVisibleIndex = currentLastIndex

            await ArtworkManager.shared.prefetch(for: albumsToPrefetch)
        }
        .onDisappear {
            Task(priority: .medium) {
                await ArtworkManager.shared.cancelPrefetching()
            }
        }
    }
}
