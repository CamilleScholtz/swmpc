//
//  QueueView.swift
//  swmpc
//
//  Created by Camille Scholtz on 06/02/2025.
//

import ButtonKit
import MPDKit
import SwiftUI

#if os(iOS)
    import SFSafeSymbols
#endif

struct QueueView: View {
    @Environment(MPD.self) private var mpd

    var body: some View {
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

#if os(iOS)
    private struct QueueHeaderView: View {
        @Environment(MPD.self) private var mpd
        @Environment(NavigationManager.self) private var navigator

        @State private var feedback = ActionFeedback()

        private var isConsume: Bool {
            mpd.status.isConsume ?? false
        }

        var body: some View {
            HStack(alignment: .center) {
                Text("Queue")
                    .font(.headline)

                Spacer()

                GlassEffectContainer {
                    HStack(spacing: Layout.Spacing.medium) {
                        AsyncButton {
                            let value = !isConsume
                            feedback.play(.selection(value ? .on : .off))

                            try await ConnectionManager.command {
                                try await $0.consume(value)
                            }
                        } label: {
                            Image(systemSymbol: isConsume ? .flameFill : .flame)
                                .contentTransition(.symbolEffect(.replace.magic(fallback: .offUp)))
                                .animation(.snappy(duration: 0.25), value: mpd.status.isConsume)
                        }
                        .accessibilityLabel(Text("Consume"))
                        .accessibilityValue(isConsume ? Text("On") : Text("Off"))
                        .accessibilityAddTraits(isConsume ? .isSelected : [])

                        if !mpd.queue.songs.isEmpty {
                            Button {
                                navigator.showClearQueueAlert = true
                            } label: {
                                Image(systemSymbol: .trash)
                            }
                            .accessibilityLabel(Text("Clear Queue"))
                        } else {
                            Button {
                                navigator.intelligenceTarget = .queue
                            } label: {
                                Image(systemSymbol: IntelligenceManager.symbol)
                            }
                            .disabled(!IntelligenceManager.isEnabled)
                            .accessibilityLabel(Text("Fill Queue with AI"))
                        }
                    }
                }
                .buttonStyle(.glass)
                .actionFeedback(feedback)
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
            // The matching `.reorderContainer` lives on the `List` in
            // `AppView` that hosts this `ForEach`.
            ForEach(mpd.queue.songs, id: \.id) { song in
                SongView(for: song, source: .queue)
                    .equatable()
            }
            .reorderable()
            .mediaRowStyle()
        #elseif os(macOS)
            List {
                ForEach(mpd.queue.songs, id: \.id) { song in
                    SongView(for: song, source: .queue)
                        .equatable()
                }
                .reorderable()
                .mediaRowStyle()
            }
            .reorderContainer(for: Song.self) { difference in
                Task {
                    await difference.perform(on: mpd.queue.songs, in: .queue)
                }
            }
            .mediaListStyle()
            .scrollToItem($scrollTarget)
            .task {
                guard let song = mpd.status.song,
                      mpd.queue.songs.contains(where: { $0.id == song.id })
                else {
                    return
                }

                scrollTarget = ScrollTarget(id: song.id, animated: false)
            }
        #endif
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
