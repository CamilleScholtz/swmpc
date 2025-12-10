//
//  SongView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import MPDKit
import SwiftUI

struct SongView: View, Equatable {
    @Environment(MPD.self) private var mpd

    private let song: Song
    private let source: Source?

    init(for song: Song, source: Source? = nil) {
        self.song = song
        self.source = source
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.song == rhs.song && lhs.source == rhs.source
    }

    #if os(macOS)
        @State private var isHovering = false
        @State private var isHoveringHandle = false
        @State private var hoverHandler = HoverTaskHandler()
    #endif

    #if os(iOS)
        let trackSize: CGFloat = 30
    #elseif os(macOS)
        let trackSize: CGFloat = 20
    #endif

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: Layout.Spacing.large) {
                ZStack {
                    Text(String(song.track))
                        .font(.headline)
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    #if os(macOS)
                        Image(systemSymbol: .playFill)
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .background(
                                Rectangle()
                                    .fill(.background)
                                    .frame(width: trackSize, height: trackSize),
                            )
                            .opacity(isHovering ? 1 : 0)
                    #endif

                    if mpd.status.song == song {
                        WaveView()
                            .background(
                                Rectangle()
                                    .fill(.background)
                                    .frame(width: trackSize, height: trackSize),
                            )
                    }
                }
                .frame(width: trackSize, height: trackSize)

                VStack(alignment: .leading) {
                    Text(song.title)
                        .font(.headline)
                        .foregroundColor(mpd.status.song == song ? .accentColor : .primary)
                        .lineLimit(2)

                    Text((song.artist) + " • " + song.duration.timeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            #if os(iOS)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 10))
            #elseif os(macOS)
                .onHoverWithDebounce(handler: hoverHandler) { hovering in
                    withAnimation(.interactiveSpring) {
                        isHovering = hovering
                    }
                }
            #endif
                .onTapGesture {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command {
                            try await $0.play(song)
                        }
                    }
                }
                .contextMenu {
                    ContextMenuView(for: song, source: source)
                }

            #if os(macOS)
                if source?.isReorderable ?? false {
                    Image(systemSymbol: .line3HorizontalCircle)
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(maxHeight: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: Layout.Colors.systemBackground, location: 0.3),
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing,
                            )
                            .frame(width: trackSize * 4),
                        )
                        .opacity(isHoveringHandle ? 1 : 0)
                        .onHover { value in
                            withAnimation(.interactiveSpring) {
                                isHoveringHandle = value
                            }
                        }
                }
            #endif
        }
    }

    private struct WaveView: View {
        @Environment(MPD.self) private var mpd

        var body: some View {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !mpd.status.isPlaying)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                HStack(spacing: 1.5) {
                    bar(phase: time, speed: 1.5, low: 0.4)
                    bar(phase: time, speed: 1.2, low: 0.3)
                    bar(phase: time, speed: 1.0, low: 0.5)
                    bar(phase: time, speed: 1.7, low: 0.3)
                    bar(phase: time, speed: 1.0, low: 0.5)
                }
            }
        }

        private func bar(phase: Double, speed: Double, low: CGFloat, high: CGFloat = 1.0) -> some View {
            let normalized = (sin(phase * speed * .pi * 2) + 1) / 2
            let height = low + (high - low) * normalized

            return RoundedRectangle(cornerRadius: 2)
                .fill(.secondary)
                .frame(width: 2, height: height * 12)
        }
    }
}
