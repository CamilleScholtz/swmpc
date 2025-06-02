//
//  QueuePanelView.swift
//  swmpc
//
//  Created by Camille Scholtz on 06/02/2025.
//

import SwiftUI

struct QueuePanelView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    @Binding var isShowing: Bool

    @State private var songs: [Song] = []

    private let queueChangedNotification = NotificationCenter.default
        .publisher(for: .queueChangedNotification)

    private var queueHeader: some View {
        HStack {
            Text("Queue")
                .font(.headline)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        // .background(.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(colorScheme == .dark ? .black : Color(.secondarySystemFill)),
            alignment: .bottom
        )
    }

    private var emptyQueueView: some View {
        VStack(spacing: 10) {
            Text("Queue is empty")
                .font(.headline)
            Text("Add songs from the library to play them")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var queueListView: some View {
        ScrollViewReader { proxy in
            List(songs) { song in
                SongView(for: song)
                    .listRowSeparator(.hidden)
                    .listRowInsets(.init(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5))
            }
            .listStyle(.plain)
            .safeAreaPadding(.bottom, 7.5)
            .contentMargins(.vertical, -7.5, for: .scrollIndicators)
            .environment(\.defaultMinListRowHeight, min(31.5 + 15, 50))
            .onAppear {
                if let currentSong = mpd.status.media as? Song {
                    proxy.scrollTo(currentSong.id, anchor: .center)
                }
            }
            .onChange(of: mpd.status.media?.id) { _, newId in
                if let newId {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .center)
                    }
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            queueHeader

            if songs.isEmpty {
                emptyQueueView
            } else {
                queueListView
            }
        }
        .task {
            await loadQueue()
        }
        .onReceive(queueChangedNotification) { _ in
            Task {
                await loadQueue()
            }
        }
    }

    private func loadQueue() async {
        do {
            // Always get songs from actual queue, not database
            songs = try await ConnectionManager.command().getSongsFromQueue()
        } catch {
            songs = []
        }
    }
}
