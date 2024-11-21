//
//  DetailView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import SwiftUI

struct DetailView: View {
    @Environment(Player.self) private var player
    @Environment(\.colorScheme) var colorScheme

    @Binding var path: NavigationPath

    @State private var artwork: Artwork?
    @State private var previousArtwork: Artwork?

    @State private var isBackgroundArtworkTransitioning = false
    @State private var isArtworkTransitioning = false

    var body: some View {
        VStack {
            ZStack {
                ZStack {
                    ArtworkView(image: artwork?.image)
                        .overlay(
                            Group {
                                if let image = previousArtwork?.image {
                                    ArtworkView(image: image)
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
                .saturation(1.5)
                .blur(radius: 20)
                .opacity(0.6)

                ZStack {
                    ArtworkView(image: artwork?.image)
                        .overlay(
                            Group {
                                if let image = previousArtwork?.image {
                                    ArtworkView(image: image)
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

                ArtworkView(image: artwork?.image)
                    .overlay(
                        Group {
                            if let image = previousArtwork?.image {
                                ArtworkView(image: image)
                                    .opacity(isArtworkTransitioning ? 1 : 0)
                                    .transition(.opacity)
                            }
                        }
                    )
                    .overlay(
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(colorScheme == .dark ? 0.4 : 0.6), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                                .blendMode(.screen)

                            RoundedRectangle(cornerRadius: 10)
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
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.2), radius: 16)
                    .frame(width: 250)
                    .onTapGesture {
                        guard let uri = player.current?.albumUri else {
                            return
                        }

                        Task(priority: .userInitiated) {
                            guard let media = await player.queue.get(for: uri, using: .album) else {
                                return
                            }
                            
                            path.append(media)
                        }
                    }
            }
            .offset(y: -25)
            .zIndex(100)

            Spacer()

            FooterView()
                .frame(height: 80)
        }
        .frame(minWidth: 520, minHeight: 520)
        .onChange(of: player.current) {
            guard let current = player.current else {
                return
            }

            Task(priority: .userInitiated) {
                await player.setArtwork(for: current)
                artwork = player.getArtwork(for: current)
            }
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

        @State private var loaded = false

        var body: some View {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .opacity(loaded ? 1 : 0)
                    .background(Color(.accent).opacity(0.1))
                    .animation(.spring, value: loaded)
                    .onAppear {
                        loaded = true
                    }
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemFill).opacity(0.3))
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
            }
        }
    }

    struct FooterView: View {
        @Environment(Player.self) private var player

        var body: some View {
            VStack(alignment: .leading, spacing: 7) {
                Text(player.current?.title ?? "Unknown song")
                    .font(.system(size: 18))
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

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
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)

                Image(systemName: ((player.status.isPlaying ?? false) ? "pause" : "play") + ".fill")
                    .font(.system(size: 30))
            }
            .scaleEffect(hover ? 1.2 : 1)
            .animation(.interactiveSpring, value: hover)
            .onHover(perform: { value in
                hover = value
            })
            .onTapGesture(perform: {
                Task(priority: .userInitiated) {
                    await player.pause(player.status.isPlaying ?? false)
                }
            })
        }
    }

    struct PreviousView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: "backward.fill")
                .font(.system(size: 18))
                .padding(12)
                .scaleEffect(hover ? 1.2 : 1)
                .animation(.interactiveSpring, value: hover)
                .onHover(perform: { value in
                    hover = value
                })
                .onTapGesture(perform: {
                    Task(priority: .userInitiated) {
                        await player.previous()
                    }
                })
        }
    }

    struct NextView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: "forward.fill")
                .font(.system(size: 18))
                .padding(12)
                .scaleEffect(hover ? 1.2 : 1)
                .animation(.interactiveSpring, value: hover)
                .onHover(perform: { value in
                    hover = value
                })
                .onTapGesture(perform: {
                    Task(priority: .userInitiated) {
                        await player.next()
                    }
                })
        }
    }

    struct RandomView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            ZStack {
                Image(systemName: "shuffle")
                    .padding(10)
                    .scaleEffect(hover ? 1.2 : 1)
                    .animation(.interactiveSpring, value: hover)
                    .onHover(perform: { value in
                        hover = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            await player.setRandom(!(player.status.isRandom ?? false))
                        }
                    })

                if player.status.isRandom ?? false {
                    Circle()
                        .fill(Color(.accent))
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: 12)
                }
            }
        }
    }

    struct RepeatView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            ZStack {
                Image(systemName: "repeat")
                    .padding(10)
                    .scaleEffect(hover ? 1.2 : 1)
                    .animation(.interactiveSpring, value: hover)
                    .onHover(perform: { value in
                        hover = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            await player.setRepeat(!(player.status.isRepeat ?? false))
                        }
                    })

                if player.status.isRepeat ?? false {
                    Circle()
                        .fill(Color(.accent))
                        .frame(width: 3.5, height: 3.5)
                        .offset(y: 12)
                }
            }
        }
    }

    struct ProgressView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

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
                                    width: max(0, (player.status.elapsed ?? 0) / (player.current?.duration ?? 100) * geometry.size.width) + 4,
                                    height: 3
                                )

                            Circle()
                                .fill(Color(.accent))
                                .frame(width: 8, height: 8)
                                .scaleEffect(hover ? 1.5 : 1)
                                .animation(.spring, value: hover)
                        }
                        .animation(.spring, value: player.status.elapsed)
                    }
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        Task(priority: .userInitiated) {
                            await player.seek((value.location.x / geometry.size.width) * (player.current?.duration ?? 100))
                        }
                    })
                    .onHover(perform: { value in
                        hover = value
                    })

                    HStack(alignment: .center) {
                        Text(player.status.elapsed?.timeString ?? "-:--")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(player.current?.duration?.timeString ?? "-:--")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                player.status.trackElapsed = true
            }
            .onDisappear {
                player.status.trackElapsed = false
            }
        }
    }
}
