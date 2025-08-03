//
//  QueuePanelView.swift
//  swmpc
//
//  Created by Camille Scholtz on 06/02/2025.
//

import ButtonKit
import SwiftUI

struct QueuePanelView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    @Binding var showQueuePanel: Bool

    @State private var showClearQueueAlert = false
    @State private var showIntelligenceQueueSheet = false

    private let fillIntelligenceQueueNotification = NotificationCenter.default
        .publisher(for: .fillIntelligenceQueueNotification)

    var body: some View {
        VStack(spacing: 0) {
            if mpd.queue.songs.isEmpty {
                EmptyQueueView()
            } else {
                QueueView()
            }
        }
        .alert("Clear Queue", isPresented: $showClearQueueAlert) {
            Button("Cancel", role: .cancel) {}

            AsyncButton("Clear Queue", role: .destructive) {
                try await ConnectionManager.command().clearQueue()
            }
        } message: {
            Text("This will remove all songs from the queue.")
        }
        .onReceive(fillIntelligenceQueueNotification) { _ in
            showIntelligenceQueueSheet = true
        }
        .sheet(isPresented: $showIntelligenceQueueSheet) {
            IntelligenceView(target: .queue, showSheet: $showIntelligenceQueueSheet)
        }
    }

    struct EmptyQueueView: View {
        var body: some View {
            VStack(spacing: 10) {
                Text("Queue is empty")
                    .font(.headline)
                Text("Add songs from the library to play them")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct QueueView: View {
        @Environment(MPD.self) private var mpd
        @Environment(\.colorScheme) private var colorScheme

        private var songs: [Song] {
            mpd.queue.songs
        }

        @State private var scrollProxy: ScrollViewProxy?
        @State private var hasScrolledToInitial = false

        private let performScrollNotification = NotificationCenter.default
            .publisher(for: .performScrollNotification)

        var body: some View {
            ListView(rowHeight: 31.5 + 15) { proxy in
                List {
                    ForEach(songs, id: \.id) { song in
                        RowView(media: song)
                    }
                    .onMove { source, destination in
                        move(from: source, to: destination)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5))
                .onAppear {
                    scrollProxy = proxy

                    // Scroll to current song on initial appearance
                    if !hasScrolledToInitial {
                        hasScrolledToInitial = true
                        Task {
                            // Wait a moment for the view to settle
                            try? await Task.sleep(for: .milliseconds(100))
                            requestScroll(to: .currentMedia, animate: false)
                        }
                    }
                }
            }
            .onReceive(performScrollNotification) { notification in
                guard let scrollProxy else { return }
                guard let request = notification.object as? ScrollManager.ScrollRequest else { return }

                Task {
                    switch request.destination {
                    case .currentMedia:
                        try? await scrollToCurrent(proxy: scrollProxy, animate: request.animate)
                    case let .specificItem(id):
                        scrollProxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }

        private func requestScroll(to destination: ScrollManager.ScrollDestination, animate: Bool = true) {
            let request = ScrollManager.ScrollRequest(destination: destination, animate: animate)
            NotificationCenter.default.post(name: .performScrollNotification, object: request)
        }

        private func move(from source: IndexSet, to destination: Int) {
            Task {
                guard let index = source.first,
                      index >= 0,
                      index < songs.count,
                      destination >= 0,
                      destination <= songs.count
                else {
                    return
                }

                let song = songs[index]
                let adjustedTo = index < destination ? destination - 1 : destination
                try? await ConnectionManager.command().move(song, to: adjustedTo, in: .queue)
            }
        }

        private func scrollToCurrent(proxy: ScrollViewProxy, animate _: Bool = true) async throws {
            guard let currentSong = mpd.status.song else {
                throw ViewError.missingData
            }

            guard let id = mpd.queue.songs.first(where: { $0.url == currentSong.url })?.id else {
                throw ViewError.missingData
            }

            proxy.scrollTo(id, anchor: .center)
        }
    }
}
