//
//  DetailView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import SwiftUI

struct DetailView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) var colorScheme

    @Binding var path: NavigationPath

    @State private var artwork: NSImage?
    @State private var previousArtwork: NSImage?

    @State private var isBackgroundArtworkTransitioning = false
    @State private var isArtworkTransitioning = false

    @State private var isHovering = false

    var body: some View {
        VStack {
            ZStack {
                ZStack {
                    ZStack {
                        ArtworkView(image: artwork)
                            .overlay(
                                Group {
                                    if let previousArtwork {
                                        ArtworkView(image: previousArtwork)
                                            .opacity(isBackgroundArtworkTransitioning ? 1 : 0)
                                            .transition(.opacity)
                                    }
                                }
                            )

                        Rectangle()
                            .opacity(0)
                            .background(.ultraThinMaterial)
                    }
                    .scaledToFit()
                    .mask(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .clear]),
                            center: .center,
                            startRadius: -25,
                            endRadius: 225
                        )
                    )
                    .offset(y: 20)
                    .blur(radius: 20)
                    .opacity(0.6)

                    ZStack {
                        ArtworkView(image: artwork)
                            .overlay(
                                Group {
                                    if let previousArtwork {
                                        ArtworkView(image: previousArtwork)
                                            .opacity(isBackgroundArtworkTransitioning ? 1 : 0)
                                            .transition(.opacity)
                                    }
                                }
                            )

                        Rectangle()
                            .opacity(0)
                            .background(.ultraThinMaterial)
                    }
                    .scaledToFit()
                    .mask(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .clear]),
                            center: .center,
                            startRadius: -25,
                            endRadius: 225
                        )
                    )
                    .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: 0))
                    .offset(y: 105)
                    .blur(radius: 5)
                }
                .saturation(1.5)
                .blendMode(colorScheme == .dark ? .softLight : .normal)

                ArtworkView(image: artwork)
                    .overlay(
                        Group {
                            if let previousArtwork {
                                ArtworkView(image: previousArtwork)
                                    .opacity(isArtworkTransitioning ? 1 : 0)
                                    .transition(.opacity)
                            }
                        }
                    )
                    .overlay(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(colorScheme == .dark ? 0.4 : 0.6), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                                .blendMode(.screen)

                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.clear, Color.black.opacity(colorScheme == .dark ? 0.6 : 0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                                .blendMode(.multiply)
                        }
                    )
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.2), radius: 16)
                    .frame(width: 250)
                    .scaleEffect(isHovering ? 1.02 : 1)
                    .animation(.spring, value: isHovering)
                    .onHover(perform: { value in
                        isHovering = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            guard let song = mpd.status.song else {
                                return
                            }

                            guard let media = try? await mpd.queue.get(for: .album, using: song) else {
                                return
                            }

                            // TODO: Check if last in path is not the same as current media.
                            // TODO: Very hacky?
                            path.removeLast(path.count)
                            try? await Task.sleep(for: .milliseconds(1))
                            path.append(media)
                        }
                    })
            }
            .offset(y: -25)
            .zIndex(100)

            Spacer()

            FooterView()
                .frame(height: 80)
        }
        .ignoresSafeArea()
        .frame(minWidth: 520, minHeight: 520)
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                return
            }

            guard let data = try? await ArtworkManager.shared.get(using: song.url, shouldCache: false) else {
                return
            }
            artwork = NSImage(data: data)
        }
        .onChange(of: artwork) { previous, _ in
            previousArtwork = previous

            isBackgroundArtworkTransitioning = true
            withAnimation(.spring(duration: 0.5)) {
                isBackgroundArtworkTransitioning = false
            }
            isArtworkTransitioning = true
            withAnimation(.interactiveSpring) {
                isArtworkTransitioning = false
            }
        }
    }

    struct ArtworkView: View {
        let image: NSImage?

        var body: some View {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                } else {
                    Color(.secondarySystemFill)
                }
            }
            .transition(.opacity.animation(.spring))
            .aspectRatio(contentMode: .fit)
        }
    }

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
    }

    struct PauseView: View {
        @Environment(MPD.self) private var mpd

        @State private var isHovering = false

        var body: some View {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)

                Image(systemName: (mpd.status.isPlaying ? "pause" : "play") + ".fill")
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
            Image(systemName: "backward.fill")
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
            Image(systemName: "forward.fill")
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
                Image(systemName: "shuffle")
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

        var body: some View {
            Image(systemName: "heart.fill")
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
                    isFavorited.toggle()

                    Task(priority: .userInitiated) {
                        guard let song = mpd.status.song else {
                            return
                        }

                        if isFavorited {
                            try? await ConnectionManager.command().addToFavorites(songs: [song])
                        } else {
                            try? await ConnectionManager.command().removeFromFavorites(songs: [song])
                        }
                    }
                })
                .onChange(of: mpd.status.song) {
                    guard let song = mpd.status.song else {
                        return
                    }

                    // TODO: On launch, favorites is not yet set.
                    isFavorited = mpd.queue.favorites.contains { $0.url == song.url }
                }
        }
    }

    struct RepeatView: View {
        @Environment(MPD.self) private var mpd

        @State private var isHovering = false

        var body: some View {
            ZStack {
                Image(systemName: "repeat")
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

        @State private var isHovering = false

        var body: some View {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.secondarySystemFill))
                            .frame(width: geometry.size.width, height: 3)

                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.accent))
                                .frame(
                                    width: max(0, (mpd.status.elapsed ?? 0) / (mpd.status.song?.duration ?? 100) * geometry.size.width) + 4,
                                    height: 3
                                )

                            Circle()
                                .fill(Color(.accent))
                                .frame(width: 8, height: 8)
                                .scaleEffect(isHovering ? 1.5 : 1)
                                .animation(.spring, value: isHovering)
                        }
                        .animation(.spring, value: mpd.status.elapsed)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command().seek((value.location.x / geometry.size.width) * (mpd.status.song?.duration ?? 100))
                        }
                    })
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
