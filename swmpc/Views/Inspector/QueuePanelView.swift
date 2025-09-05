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
    private let showClearQueueAlertNotification = NotificationCenter.default
        .publisher(for: .showClearQueueAlertNotification)

    var body: some View {
        VStack(spacing: 0) {
            if mpd.queue.songs.isEmpty {
                EmptyQueueView()
            } else {
                QueueView()
            }
        }
        .background(.background)
        .alert("Clear Queue", isPresented: $showClearQueueAlert) {
            Button("Cancel", role: .cancel) {}

            AsyncButton("Clear", role: .destructive) {
                try await ConnectionManager.command().clearQueue()
            }
        } message: {
            Text("Are you sure you want to clear the queue?")
        }
        .onReceive(fillIntelligenceQueueNotification) { _ in
            showIntelligenceQueueSheet = true
        }
        .onReceive(showClearQueueAlertNotification) { _ in
            showClearQueueAlert = true
        }
        .sheet(isPresented: $showIntelligenceQueueSheet) {
            IntelligenceView(target: .queue, showSheet: $showIntelligenceQueueSheet)
        }
    }

    struct QueueView: View {
        @Environment(MPD.self) private var mpd

        @State private var scrollTo: String?

        var body: some View {
            CollectionView(data: mpd.queue.songs, rowHeight: Layout.RowHeight.song + Layout.Padding.large) { song in
                RowView(media: song, source: .queue)
            }
            .contentMargins(.bottom, Layout.Spacing.small)
            .scrollTo($scrollTo, animated: false)
            .reorderable { sourceIndices, destination in
                Task {
                    await handleReorder(sourceIndices: sourceIndices, destination: destination)
                }
            }
            .ignoresSafeArea(edges: .vertical)
            .onAppear {
                guard let song = mpd.status.song else {
                    return
                }

                // Defer scrolling to avoid state modification during view update
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    scrollTo = song.id
                }
            }
        }

        private func handleReorder(sourceIndices: IndexSet, destination: Int) async {
            guard let sourceIndex = sourceIndices.first,
                  sourceIndex < mpd.queue.songs.count
            else {
                return
            }

            let song = mpd.queue.songs[sourceIndex]

            do {
                try await ConnectionManager.command().move(song, to: destination, in: .queue)
                try await mpd.queue.set()
            } catch {
                print("Failed to reorder song: \(error)")
            }
        }
    }

    struct EmptyQueueView: View {
        var body: some View {
            VStack {
                Text("Queue is empty")
                    .font(.headline)

                Text("Add media from the library")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
