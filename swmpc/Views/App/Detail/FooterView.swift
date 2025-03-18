//
//  FooterView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct FooterView: View {
    @Environment(MPD.self) private var mpd

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center) {
                Text(mpd.status.song?.title ?? "No song playing")
                    .font(.system(size: 18))
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                Spacer()

                FavoriteView()
            }

            ProgressView()
        }

        VStack {
            HStack(alignment: .center, spacing: 40) {
                RepeatView()

                HStack(spacing: 20) {
                    PreviousView()
                    PauseView()
                    NextView()
                }

                RandomView()
            }
        }
    }

    struct PauseView: View {
        @Environment(MPD.self) private var mpd

        @State private var isHovering = false

        var body: some View {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)

                Image(systemSymbol: mpd.status.isPlaying ? .pauseFill : .playFill)
                    .font(.system(size: 30))
            }
            .scaleEffect(isHovering ? 1.2 : 1)
            .animation(.interactiveSpring, value: isHovering)
            .onHover(perform: { value in
                isHovering = value
            })
            .onTapGesture(perform: {
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().pause(mpd.status.isPlaying)
                }
            })
        }
    }

    struct PreviousView: View {
        @State private var isHovering = false

        var body: some View {
            Image(systemSymbol: .backwardFill)
                .font(.system(size: 18))
                .padding(12)
                .scaleEffect(isHovering ? 1.2 : 1)
                .animation(.interactiveSpring, value: isHovering)
                .onHover(perform: { value in
                    isHovering = value
                })
                .onTapGesture(perform: {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().previous()
                    }
                })
        }
    }

    struct NextView: View {
        @State private var isHovering = false

        var body: some View {
            Image(systemSymbol: .forwardFill)
                .font(.system(size: 18))
                .padding(12)
                .scaleEffect(isHovering ? 1.2 : 1)
                .animation(.interactiveSpring, value: isHovering)
                .onHover(perform: { value in
                    isHovering = value
                })
                .onTapGesture(perform: {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().next()
                    }
                })
        }
    }

    struct RandomView: View {
        @Environment(MPD.self) private var mpd

        @State private var isHovering = false

        var body: some View {
            ZStack {
                Image(systemSymbol: .shuffle)
                    .padding(10)
                    .scaleEffect(isHovering ? 1.2 : 1)
                    .animation(.interactiveSpring, value: isHovering)
                    .onHover(perform: { value in
                        isHovering = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command().random(!(mpd.status.isRandom ?? false))
                        }
                    })

                if mpd.status.isRandom ?? false {
                    Circle()
                        .fill(Color(.accent))
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: 12)
                }
            }
        }
    }

    struct FavoriteView: View {
        @Environment(MPD.self) private var mpd

        @State private var isHovering = false
        @State private var isFavorited = false

        private let addCurrentToFavoritesNotifaction = NotificationCenter.default
            .publisher(for: .addCurrentToFavoritesNotifaction)

        var body: some View {
            Image(systemSymbol: .heartFill)
                .scaleEffect(isHovering ? 1.2 : 1)
                .animation(.interactiveSpring, value: isHovering)
                .foregroundColor(isFavorited ? .red : Color(.secondarySystemFill))
                .opacity(isFavorited ? 0.7 : 1)
                .animation(.interactiveSpring, value: isFavorited)
                .scaleEffect(isFavorited ? 1.1 : 1)
                .animation(isFavorited ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true) : .default, value: isFavorited)
                .onHover(perform: { value in
                    isHovering = value
                })
                .onTapGesture(perform: {
                    NotificationCenter.default.post(name: .addCurrentToFavoritesNotifaction, object: nil)
                })
                .onReceive(addCurrentToFavoritesNotifaction) { _ in
                    Task(priority: .userInitiated) {
                        guard let song = mpd.status.song else {
                            return
                        }

                        isFavorited.toggle()

                        if isFavorited {
                            try? await ConnectionManager.command().addToFavorites(songs: [song])
                        } else {
                            try? await ConnectionManager.command().removeFromFavorites(songs: [song])
                        }
                    }
                }
                .onChange(of: mpd.status.song) {
                    guard let song = mpd.status.song else {
                        return
                    }

                    isFavorited = mpd.queue.favorites.contains { $0.url == song.url }
                }
        }
    }

    struct RepeatView: View {
        @Environment(MPD.self) private var mpd

        @State private var isHovering = false

        var body: some View {
            ZStack {
                Image(systemSymbol: .repeat)
                    .padding(10)
                    .scaleEffect(isHovering ? 1.2 : 1)
                    .animation(.interactiveSpring, value: isHovering)
                    .onHover(perform: { value in
                        isHovering = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command().repeat(!(mpd.status.isRepeat ?? false))
                        }
                    })

                if mpd.status.isRepeat ?? false {
                    Circle()
                        .fill(Color(.accent))
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: 12)
                }
            }
        }
    }

    struct ProgressView: View {
        @Environment(MPD.self) private var mpd

        @State private var dragProgress: CGFloat? = nil
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

        private var displayProgress: CGFloat {
            dragProgress ?? progress
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
                            .frame(width: displayProgress * geometry.size.width, height: 3)
                            .animation(.spring, value: displayProgress)

                        Circle()
                            .fill(Color(.accent))
                            .frame(width: 8, height: 8)
                            .scaleEffect(isHovering ? 1.5 : 1)
                            .animation(.spring, value: isHovering)
                            .offset(x: (displayProgress * geometry.size.width) - 4)
                            .animation(.spring, value: displayProgress)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragProgress = min(max(value.location.x / geometry.size.width, 0), 1)
                            }
                            .onEnded { value in
                                let time = min(max(value.location.x / geometry.size.width, 0), 1) * (mpd.status.song?.duration ?? 100)

                                Task(priority: .userInitiated) {
                                    try? await ConnectionManager.command().seek(time)
                                    dragProgress = nil
                                }
                            }
                    )
                    .onHover(perform: { value in
                        isHovering = value
                    })

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
            .onAppear {
                mpd.status.trackElapsed = true
            }
            .onDisappear {
                mpd.status.trackElapsed = false
            }
        }
    }
}
