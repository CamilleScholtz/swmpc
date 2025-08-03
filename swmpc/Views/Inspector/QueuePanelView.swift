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

        
        @State private var hasScrolledToInitial = false

        private let performScrollNotification = NotificationCenter.default
            .publisher(for: .performScrollNotification)
        
        private var songsLookup: [String: Song] {
            Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        }

        var body: some View {
            let lookup = songsLookup
            RecyclingScrollView(rowIDs: songs.map(\.id), rowHeight: 31.5 + 15) { id in
                if let song = lookup[id] {
                    RowView(media: song)
                }
            }
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

        
    }
}