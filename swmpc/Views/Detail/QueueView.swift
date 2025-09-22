//
//  QueueView.swift
//  swmpc
//
//  Created by Camille Scholtz on 06/02/2025.
//

import ButtonKit
import SwiftUI

#if os(iOS)
    import SFSafeSymbols
#endif

struct QueueView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    @State private var showClearQueueAlert = false
    @State private var showIntelligenceQueueSheet = false

    private let fillIntelligenceQueueNotification = NotificationCenter.default
        .publisher(for: .fillIntelligenceQueueNotification)
    private let showClearQueueAlertNotification = NotificationCenter.default
        .publisher(for: .showClearQueueAlertNotification)

    var body: some View {
        Group {
            #if os(iOS)
                Group {
                    QueueHeaderView(
                        showClearQueueAlert: $showClearQueueAlert,
                        showIntelligenceQueueSheet: $showIntelligenceQueueSheet,
                    )
                    .listRowSeparator(.visible)
                    .listRowInsets(.horizontal, Layout.Padding.large)

                    if mpd.queue.songs.isEmpty {
                        EmptyQueueView()
                            .mediaRowStyle()
                    } else {
                        MediaList()
                    }
                }
            #else
                VStack(spacing: 0) {
                    if mpd.queue.songs.isEmpty {
                        EmptyQueueView()
                    } else {
                        MediaList()
                    }
                }
                .background(.background)
            #endif
        }
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
}

#if os(iOS)
    private struct QueueHeaderView: View {
        @Environment(MPD.self) private var mpd

        @Binding var showClearQueueAlert: Bool
        @Binding var showIntelligenceQueueSheet: Bool

        var body: some View {
            HStack(alignment: .center) {
                Text("Queue")
                    .font(.headline)

                Spacer()

                HStack(spacing: Layout.Spacing.medium) {
                    AsyncButton {
                        try await ConnectionManager.command().consume(!(mpd.status.isConsume ?? false))
                    } label: {
                        Image(systemSymbol: mpd.status.isConsume ?? false ? .flameFill : .flame)
                    }

                    if !mpd.queue.songs.isEmpty {
                        Button {
                            showClearQueueAlert = true
                        } label: {
                            Image(systemSymbol: .trash)
                        }
                    } else {
                        Button {
                            showIntelligenceQueueSheet = true
                        } label: {
                            Image(systemSymbol: .sparkles)
                        }
                        .disabled(!IntelligenceManager.shared.isEnabled)
                    }
                }
                .buttonStyle(.glass)
            }
        }
    }
#endif

private struct MediaList: View {
    @Environment(MPD.self) private var mpd

    #if os(macOS)
        @State private var scrollTarget: ScrollTarget?
    #endif

    var body: some View {
        #if os(iOS)
            ForEach(mpd.queue.songs, id: \.id) { song in
                SongView(for: song, source: .queue)
                    .equatable()
                    .mediaRowStyle()
            }
            .onMove { indices, destination in
                Task {
                    await handleReorder(indices: indices, destination: destination)
                }
            }
        #elseif os(macOS)
            List {
                ForEach(mpd.queue.songs, id: \.id) { song in
                    SongView(for: song, source: .queue)
                        .equatable()
                        .mediaRowStyle()
                }
                .onMove { indices, destination in
                    Task {
                        await handleReorder(indices: indices, destination: destination)
                    }
                }
            }
            .mediaListStyle()
            .scrollToItem($scrollTarget)
            .task {
                guard let song = mpd.status.song else {
                    return
                }

                scrollTarget = ScrollTarget(id: song.id, animated: false)
                try? await Task.sleep(for: .milliseconds(200))
                scrollTarget = ScrollTarget(id: song.id, animated: false)
            }
        #endif
    }

    private func handleReorder(indices: IndexSet, destination: Int) async {
        guard let sourceIndex = indices.first,
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

private struct EmptyQueueView: View {
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
