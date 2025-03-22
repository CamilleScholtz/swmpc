//
//  AlbumsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct AlbumsView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator

    @AppStorage(Setting.scrollToCurrent) private var scrollToCurrent = false

    @State private var visibleRange: Range<Int>?

    private var albums: [Album] {
        mpd.queue.media as? [Album] ?? []
    }

    var body: some View {
        ForEach(Array(albums.enumerated()), id: \.element.id) { index, album in
            AlbumView(for: album)
                .id(album.id)
                .onAppear {
                    updateVisibleRange(currentIndex: index)
                }
                .onDisappear {
                    updateVisibleRange(currentIndex: index, isDisappearing: true)
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
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: song, using: .album)
        }
        .task(id: visibleRange, priority: .background) {
            guard let range = visibleRange, !albums.isEmpty, !Task.isCancelled else {
                return
            }

            let lowerBound = max(0, range.lowerBound - 2)
            let upperBound = min(albums.count, range.upperBound + 2)

            let prefetchRange = lowerBound ..< upperBound
            let albumsToPrefetch = prefetchRange.map {
                albums[$0]
            }

            await ArtworkManager.shared.prefetch(for: albumsToPrefetch)
        }
        .onDisappear {
            Task(priority: .high) {
                await ArtworkManager.shared.cancelPrefetching()
            }
        }
    }

    private func updateVisibleRange(currentIndex: Int, isDisappearing: Bool = false) {
        guard !albums.isEmpty else {
            return
        }

        if var range = visibleRange {
            if isDisappearing {
                if currentIndex == range.lowerBound {
                    range = (currentIndex + 1) ..< range.upperBound
                } else if currentIndex == range.upperBound - 1 {
                    range = range.lowerBound ..< currentIndex
                }
            } else {
                range = min(range.lowerBound, currentIndex) ..< max(range.upperBound, currentIndex + 1)
            }

            visibleRange = range
        } else {
            visibleRange = currentIndex ..< (currentIndex + 1)
        }
    }
}
