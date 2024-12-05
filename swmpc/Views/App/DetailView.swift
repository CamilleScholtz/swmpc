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

    @State private var artwork: NSImage?
    @State private var previousArtwork: NSImage?

    @State private var isBackgroundArtworkTransitioning = false
    @State private var isArtworkTransitioning = false

    @State private var hover = false

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
                    .scaleEffect(hover ? 1.02 : 1)
                    .animation(.spring, value: hover)
                    .onHover(perform: { value in
                        hover = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            guard let song = player.currentSong else {
                                return
                            }

                            guard let media = await player.queue.get(for: .album, using: song) else {
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
        .ignoresSafeArea(.all)
        .frame(minWidth: 520, minHeight: 520)
        .task(id: player.currentSong) {
            guard let song = player.currentSong else {
                return
            }

            artwork = await NSImage(data: try! CommandManager.shared.getArtworkData(for: song.uri, shouldCache: false))
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
                    .background(Color(.secondarySystemFill))
                    .animation(.spring, value: loaded)
                    .onAppear {
                        loaded = true
                    }
            } else {
                Rectangle()
                    .fill(Color(.secondarySystemFill))
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
            }
        }
    }

    struct VinylView: View {
        @Environment(Player.self) private var player

        var body: some View {
            ZStack {
                Circle()
                    .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .stroke(Color(red: 0.6, green: 0.6, blue: 0.6), lineWidth: 0.3)

                ForEach(0 ..< 37) { i in
                    let color = Double.random(in: 0.1 ..< 0.3)

                    Circle()
                        .stroke(Color(red: color, green: color, blue: color), lineWidth: 0.5)
                        .scaleEffect(0.96 - CGFloat(i) * 0.015)
                }

                ForEach(0 ..< 5) { i in
                    let color = 0.03
                    let distance = Double.random(in: 0.11 ..< 0.13)

                    Circle()
                        .stroke(Color(red: color, green: color, blue: color), lineWidth: 0.8)
                        .scaleEffect(0.95 - CGFloat(i) * distance)
                }

                Circle()
                    .fill(Color.clear)
                    .overlay(
                        ZStack {
                            HStack {
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.clear, location: 0.38),
                                        .init(color: Color(red: 0.58, green: 0.58, blue: 0.58), location: 0.5),
                                        .init(color: Color.clear, location: 0.62),
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .rotation3DEffect(.degrees(80), axis: (x: 0, y: 1, z: 0), perspective: 3)
                                .scaleEffect(x: 2.7)
                                .offset(x: 35)

                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.clear, location: 0.38),
                                        .init(color: Color(red: 0.55, green: 0.55, blue: 0.55), location: 0.5),
                                        .init(color: Color.clear, location: 0.62),
                                    ]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                                .rotation3DEffect(.degrees(-80), axis: (x: 0, y: 1, z: 0), perspective: 3)
                                .scaleEffect(x: 2.7)
                                .offset(x: -35)
                            }
                            .rotationEffect(.degrees(-30))

                            HStack {
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.clear, location: 0.38),
                                        .init(color: Color(red: 0.5, green: 0.5, blue: 0.5), location: 0.5),
                                        .init(color: Color.clear, location: 0.62),
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .rotation3DEffect(.degrees(80), axis: (x: 0, y: 1, z: 0), perspective: 3)
                                .scaleEffect(x: 2.7)
                                .offset(x: 35)

                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.clear, location: 0.38),
                                        .init(color: Color(red: 0.51, green: 0.51, blue: 0.51), location: 0.5),
                                        .init(color: Color.clear, location: 0.62),
                                    ]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                                .rotation3DEffect(.degrees(-80), axis: (x: 0, y: 1, z: 0), perspective: 3)
                                .scaleEffect(x: 2.7)
                                .offset(x: -35)
                            }
                            .rotationEffect(.degrees(55))
                        }
                        .mask(Circle())
                    )
                    .blendMode(.difference)

                Circle()
                    .fill(Color(red: 0.13, green: 0.13, blue: 0.13).opacity(0.6))
                    .frame(width: 97, height: 97)
            }
        }
    }

    struct FooterView: View {
        @Environment(Player.self) private var player

        var body: some View {
            VStack(alignment: .leading, spacing: 7) {
                Text(player.currentSong?.title ?? "No song playing")
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
                    await CommandManager.shared.pause(player.status.isPlaying ?? false)
                }
            })
        }
    }

    struct PreviousView: View {
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
                        await CommandManager.shared.previous()
                    }
                })
        }
    }

    struct NextView: View {
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
                        await CommandManager.shared.next()
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
                            await CommandManager.shared.random(!(player.status.isRandom ?? false))
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
                            await CommandManager.shared.repeat(!(player.status.isRepeat ?? false))
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
                                    width: max(0, (player.status.elapsed ?? 0) / (player.currentSong?.duration ?? 100) * geometry.size.width) + 4,
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
                            await CommandManager.shared.seek((value.location.x / geometry.size.width) * (player.currentSong?.duration ?? 100))
                        }
                    })
                    .onHover(perform: { value in
                        hover = value
                    })

                    HStack(alignment: .center) {
                        Text(player.status.elapsed?.timeString ?? "0:00")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text(player.currentSong?.duration.timeString ?? "0:00")
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
