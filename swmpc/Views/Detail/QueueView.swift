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

    var body: some View {
        Group {
            #if os(iOS)
                Group {
                    QueueHeaderView()
                        .listRowSeparator(.visible)
                        .listRowInsets(.horizontal, Layout.Padding.large)

                    if mpd.queue.songs.isEmpty {
                        EmptyQueueView()
                            .mediaRowStyle()
                    } else {
                        MediaList()
                    }
                }
            #elseif os(macOS)
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
    }
}

#if os(iOS)
    private struct QueueHeaderView: View {
        @Environment(MPD.self) private var mpd
        @Environment(NavigationManager.self) private var navigator

        var body: some View {
            HStack(alignment: .center) {
                Text("Queue")
                    .font(.headline)

                Spacer()

                GlassEffectContainer {
                    HStack(spacing: Layout.Spacing.medium) {
                        AsyncButton {
                            try await ConnectionManager.command {
                                try await $0.consume(!(mpd.status.isConsume ?? false))
                            }
                        } label: {
                            Image(systemSymbol: mpd.status.isConsume ?? false ? .flameFill : .flame)
                        }

                        if !mpd.queue.songs.isEmpty {
                            Button {
                                navigator.showClearQueueAlert = true
                            } label: {
                                Image(systemSymbol: .trash)
                            }
                        } else {
                            Button {
                                navigator.intelligenceTarget = .queue
                                navigator.showIntelligenceSheet = true
                            } label: {
                                Image(systemSymbol: .sparkles)
                            }
                            .disabled(!IntelligenceManager.isEnabled)
                        }
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
                guard let song = mpd.status.song,
                      let index = mpd.queue.songs.firstIndex(where: { $0.id == song.id })
                else {
                    return
                }

                scrollTarget = ScrollTarget(index: index, animated: false)
            }
        #endif
    }

    private func handleReorder(indices: IndexSet, destination: Int) async {
        guard let index = indices.first else {
            return
        }

        let songs = mpd.queue.songs
        guard index < songs.count else {
            return
        }

        let song = songs[index]

        try? await ConnectionManager.command {
            try await $0.move(song, to: destination, in: .queue)
        }
        try? await mpd.queue.set()
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
