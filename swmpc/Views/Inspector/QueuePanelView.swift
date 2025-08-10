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

            AsyncButton("Clear Queue", role: .destructive) {
                try await ConnectionManager.command().clearQueue()
            }
        } message: {
            Text("This will remove all songs from the queue.")
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
            CollectionView(data: mpd.queue.songs, rowHeight: Layout.RowHeight.song + Layout.Padding.large, contentMargin: EdgeInsets(top: 0, leading: 0, bottom: Layout.Spacing.small, trailing: 0), scrollTo: $scrollTo) { song in
                RowView(media: song)
            }
            .ignoresSafeArea(edges: .vertical)
            .contentMargins(.bottom, Layout.Spacing.small)
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

    struct EmptyQueueView: View {
        var body: some View {
            VStack(spacing: Layout.Spacing.medium) {
                Text("Queue is empty")
                    .font(.headline)
                Text("Add media from the library")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
