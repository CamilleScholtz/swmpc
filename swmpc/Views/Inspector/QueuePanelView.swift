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

        @State private var scrollTo: String?

        var body: some View {
            CollectionView(data: mpd.queue.songs, rowHeight: 31.5 + 15, scrollTo: $scrollTo) { song in
                RowView(media: song)
            }
            .ignoresSafeArea(edges: .top)
            .onAppear {
                guard let song = mpd.status.song else {
                    return
                }

                Task {
                    scrollTo = song.id
                    try? await Task.sleep(for: .milliseconds(100))
                    scrollTo = song.id
                }
            }
        }
    }
}
