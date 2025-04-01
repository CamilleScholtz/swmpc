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
                        previousVisibleIndex = lastVisibleIndex
                        lastVisibleIndex = index
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
        // Don't update media on song change - this breaks navigation
        .task(id: lastVisibleIndex, priority: .medium) {
            guard !albums.isEmpty, !Task.isCancelled else {
                return
            }

            let isScrollingUp = lastVisibleIndex < previousVisibleIndex

            let albumsToPrefetch = {
                let start = isScrollingUp ? max(0, lastVisibleIndex - 2) : lastVisibleIndex + 1
                let end = isScrollingUp ? lastVisibleIndex : min(albums.count, lastVisibleIndex + 3)

                return Array(albums[start ..< end])
            }()

            await ArtworkManager.shared.prefetch(for: albumsToPrefetch)
        }
        .onDisappear {
            Task(priority: .medium) {
                await ArtworkManager.shared.cancelPrefetching()
            }
        }
    }
}
