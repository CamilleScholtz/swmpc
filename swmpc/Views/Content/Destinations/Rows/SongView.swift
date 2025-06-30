//
//  SongView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SwiftUI

struct SongView: View {
    @Environment(MPD.self) private var mpd

    private let song: Song
    private let membershipContext: MembershipContext

    init(for song: Song, membershipContext: MembershipContext = .none) {
        self.song = song
        self.membershipContext = membershipContext
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
            HStack(spacing: 15) {
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
                                    .frame(width: trackSize, height: trackSize)
                            )
                            .opacity(isHovering ? 1 : 0)
                    #endif

                    WaveView()
                        .background(
                            Rectangle()
                                .fill(.background)
                                .frame(width: trackSize, height: trackSize)
                        )
                        .opacity(mpd.status.song == song ? 1 : 0)
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
                        try? await ConnectionManager.command().play(song)
                    }
                }
                .contextMenu {
                    RowContextMenuView(for: song, membershipContext: membershipContext)
                }

            if membershipContext.showsHandle {
                Image(systemSymbol: .line3HorizontalCircle)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
                    .background(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: Color(.textBackgroundColor), location: 0.3),
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: trackSize * 4)
                    )
                    .opacity(isHoveringHandle ? 1 : 0)
                    .onHover { value in
                        withAnimation(.interactiveSpring) {
                            isHoveringHandle = value
                        }
                    }
            }
        }
    }
}

struct WaveView: View {
    @Environment(MPD.self) private var mpd

    @State private var isAnimating = false

    var body: some View {
        let isPlaying = mpd.status.isPlaying

        HStack(spacing: 1.5) {
            bar(low: 0.4)
                .animation(isPlaying ? .linear(duration: 0.5).speed(1.5).repeatForever() : .linear(duration: 0.5), value: isAnimating)
            bar(low: 0.3)
                .animation(isPlaying ? .linear(duration: 0.5).speed(1.2).repeatForever() : .linear(duration: 0.5), value: isAnimating)
            bar(low: 0.5)
                .animation(isPlaying ? .linear(duration: 0.5).speed(1.0).repeatForever() : .linear(duration: 0.5), value: isAnimating)
            bar(low: 0.3)
                .animation(isPlaying ? .linear(duration: 0.5).speed(1.7).repeatForever() : .linear(duration: 0.5), value: isAnimating)
            bar(low: 0.5)
                .animation(isPlaying ? .linear(duration: 0.5).speed(1.0).repeatForever() : .linear(duration: 0.5), value: isAnimating)
        }
        .onAppear {
            isAnimating = isPlaying
        }
        .onDisappear {
            isAnimating = false
        }
        .onChange(of: isPlaying) { _, value in
            isAnimating = value
        }
    }

    private func bar(low: CGFloat = 0.0, high: CGFloat = 1.0) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.secondary)
            .frame(width: 2, height: (isAnimating ? high : low) * 12)
    }
}
