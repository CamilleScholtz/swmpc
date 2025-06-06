//
//  DetailFooterView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import ButtonKit
import SwiftUI

struct DetailFooterView: View {
    @Environment(MPD.self) private var mpd

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center) {
                Text(mpd.status.song?.title ?? "No song playing")
                #if os(iOS)
                    .font(.system(size: 22))
                #elseif os(macOS)
                    .font(.system(size: 18))
                #endif
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                Spacer()

                FavoriteView()
                    .offset(x: 4, y: 1)
            }

            PlayerProgressView()
        }

        VStack {
            #if os(iOS)
                HStack(alignment: .center, spacing: 20) {
                    RepeatView()

                    HStack(spacing: 15) {
                        PreviousView()
                        PauseView()
                        NextView()
                    }

                    RandomView()
                }
                .asyncButtonStyle(.pulse)
            #elseif os(macOS)
                HStack(alignment: .center, spacing: 40) {
                    RepeatView()

                    HStack(spacing: 20) {
                        PreviousView()
                        PauseView()
                        NextView()
                    }

                    RandomView()
                }
                .asyncButtonStyle(.pulse)
            #endif
        }
    }

    struct PauseView: View {
        @Environment(MPD.self) private var mpd

        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().pause(mpd.status.isPlaying)
            } label: {
                ZStack {
                    Circle()
                        .fill(.thinMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)

                    ZStack {
                        Image(systemSymbol: .pauseFill)
                            .font(.system(size: 30))
                            .scaleEffect(mpd.status.isPlaying ? 1 : 0.1)
                            .opacity(mpd.status.isPlaying ? 1 : 0.1)
                            .animation(.interactiveSpring(duration: 0.25), value: mpd.status.isPlaying)

                        Image(systemSymbol: .playFill)
                            .font(.system(size: 30))
                            .scaleEffect(mpd.status.isPlaying ? 0.1 : 1)
                            .opacity(mpd.status.isPlaying ? 0.1 : 1)
                            .animation(.interactiveSpring(duration: 0.25), value: mpd.status.isPlaying)
                    }
                }
            }
            .styledButton(hoverScale: 1.13)
        }
    }

    struct PreviousView: View {
        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().previous()
            } label: {
                Image(systemSymbol: .backwardFill)
                    .font(.system(size: 18))
                    .padding(12)
                    .contentShape(Circle())
            }
            .styledButton()
        }
    }

    struct NextView: View {
        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().next()
            } label: {
                Image(systemSymbol: .forwardFill)
                    .font(.system(size: 18))
                    .padding(12)
                    .contentShape(Circle())
            }
            .styledButton()
        }
    }

    struct RandomView: View {
        @Environment(MPD.self) private var mpd

        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().random(!(mpd.status.isRandom ?? false))
            } label: {
                ZStack {
                    Image(systemSymbol: .shuffle)
                        .padding(10)

                    if mpd.status.isRandom ?? false {
                        Circle()
                            .fill(Color(.accent))
                            .frame(width: 3.5, height: 3.5)
                            .offset(y: 12)
                    }
                }
                .contentShape(Circle())
            }
            .styledButton()
        }
    }

    struct RepeatView: View {
        @Environment(MPD.self) private var mpd

        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().repeat(!(mpd.status.isRepeat ?? false))
            } label: {
                ZStack {
                    Image(systemSymbol: .repeat)
                        .padding(10)

                    if mpd.status.isRepeat ?? false {
                        Circle()
                            .fill(Color(.accent))
                            .frame(width: 3.5, height: 3.5)
                            .offset(y: 12)
                    }
                }
                .contentShape(Circle())
            }
            .styledButton()
        }
    }

    struct FavoriteView: View {
        @Environment(MPD.self) private var mpd

        @State private var isFavorited = false

        var body: some View {
            AsyncButton(id: ButtonNotification.favorite) {
                guard let song = mpd.status.song else {
                    throw ViewError.missingData
                }

                isFavorited.toggle()

                if isFavorited {
                    try await ConnectionManager.command().addToFavorites(songs: [song])
                } else {
                    try await ConnectionManager.command().removeFromFavorites(songs: [song])
                }
            } label: {
                Image(systemSymbol: .heartFill)
                    .foregroundColor(isFavorited ? .red : Color(.secondarySystemFill))
                    .opacity(isFavorited ? 0.7 : 1)
                    .animation(.interactiveSpring, value: isFavorited)
                    .scaleEffect(isFavorited ? 1.1 : 1)
                    .animation(isFavorited ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: isFavorited)
                    .padding(4)
                    .contentShape(Circle())
            }
            .styledButton()
            .asyncButtonStyle(.pulse)
            .onChange(of: mpd.status.song) { _, value in
                guard let song = value else {
                    return
                }

                isFavorited = mpd.queue.favorites.contains { $0.url == song.url }
            }
            .onChange(of: mpd.queue.favorites) { _, value in
                guard let song = mpd.status.song else {
                    return
                }

                isFavorited = value.contains { $0.url == song.url }
            }
        }
    }

    struct PlayerProgressView: View {
        @Environment(MPD.self) private var mpd

        @State private var isHovering = false

        private var progress: CGFloat {
            guard let elapsed = mpd.status.elapsed,
                  let duration = mpd.status.song?.duration,
                  duration > 0
            else {
                return 0
            }

            return CGFloat(elapsed / duration)
        }

        var body: some View {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.secondarySystemFill))
                            .frame(width: geometry.size.width, height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.accent))
                            .frame(width: progress * geometry.size.width, height: 3)
                            .animation(.spring, value: progress)

                        Circle()
                            .fill(Color(.accent))
                            .frame(width: 8, height: 8)
                            .scaleEffect(isHovering ? 1.5 : 1)
                            .animation(.spring, value: isHovering)
                            .offset(x: (progress * geometry.size.width) - 4)
                            .animation(.spring, value: progress)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                Task(priority: .userInitiated) {
                                    try? await ConnectionManager.command().seek(min(max(value.location.x / geometry.size.width, 0), 1) * (mpd.status.song?.duration ?? 100))
                                }
                            }
                    )
                    .onHover { value in
                        isHovering = value
                    }

                    HStack(alignment: .center) {
                        Text(mpd.status.elapsed?.timeString ?? "0:00")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(mpd.status.song?.duration.timeString ?? "0:00")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
