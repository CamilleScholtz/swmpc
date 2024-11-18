//
//  PopoverView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct PopoverView: View {
    @Environment(Player.self) private var player
    @Environment(\.colorScheme) var colorScheme

    @State private var height = Double(250)

    @State private var artwork: Artwork?
    @State private var previousArtwork: Artwork?

    @State private var isBackgroundArtworkTransitioning = false
    @State private var isArtworkTransitioning = false

    @State private var isHovering = false
    @State private var showInfo = false

    private let willShowNotification = NotificationCenter.default
        .publisher(for: NSPopover.willShowNotification)
    private let didCloseNotification = NotificationCenter.default
        .publisher(for: NSPopover.didCloseNotification)

    var body: some View {
        ZStack(alignment: .bottom) {
            ArtworkView(image: artwork?.image)
                .overlay(
                    previousArtwork?.image != nil ? AnyView(ArtworkView(image: previousArtwork!.image)
                        .opacity(isBackgroundArtworkTransitioning ? 1 : 0)) : AnyView(EmptyView())
                )
                // .brightness(-0.4)
                .opacity(0.3)

            ArtworkView(image: artwork?.image)
                .overlay(
                    previousArtwork?.image != nil ? AnyView(ArtworkView(image: previousArtwork!.image)
                        .opacity(isArtworkTransitioning ? 1 : 0)) : AnyView(EmptyView())
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
                .scaleEffect(showInfo ? 0.7 : 1)
                .offset(y: showInfo ? -7 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 1, blendDuration: 0.7), value: showInfo)
                .shadow(color: .black.opacity(0.4), radius: 25)
                .background(.ultraThinMaterial)

            FooterView()
                .frame(height: 80)
                .offset(y: showInfo ? 0 : 80)
                .animation(.spring, value: showInfo)
        }
        .mask(
            RadialGradient(
                gradient: Gradient(colors: [.clear, .white]),
                center: .top,
                startRadius: 5,
                endRadius: 55
            )
            .offset(x: 23)
            .scaleEffect(x: 1.5)
        )
        .frame(width: 250, height: height)
        .onReceive(willShowNotification) { _ in
            Task(priority: .userInitiated) {
                guard let current = player.current else {
                    return
                }

                await player.setArtwork(for: current)
                artwork = player.getArtwork(for: current)
            }
            Task {
                // await player.status.trackElapsed()
            }
        }
        .onReceive(didCloseNotification) { _ in
            // player.status.trackingTask?.cancel()
        }
        .onChange(of: player.current) {
            guard let current = player.current, AppDelegate.shared.popover.isShown else {
                return
            }

            Task(priority: .userInitiated) {
                await player.setArtwork(for: current)
                artwork = player.getArtwork(for: current)

                updateHeight()
            }
        }
        .onChange(of: artwork) { previous, _ in
            previousArtwork = previous

            isBackgroundArtworkTransitioning = true
            withAnimation(.easeInOut(duration: 0.5)) {
                isBackgroundArtworkTransitioning = false
            }
            isArtworkTransitioning = true
            withAnimation(.easeInOut(duration: 0.1)) {
                isArtworkTransitioning = false
            }
        }
        .onHover { value in
            if !value {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if !isHovering {
                        showInfo = false || !(player.status.isPlaying ?? false)
                    }
                }
            } else {
                showInfo = true
            }

            isHovering = value
        }
    }

    private func updateHeight() {
        guard let image = artwork?.image else {
            height = 250
            return
        }

        height = (Double(image.size.height) / Double(image.size.width) * 250).rounded(.down)
    }

    struct ArtworkView: View {
        let image: NSImage?

        var body: some View {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 250)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 25))
                    .blendMode(.overlay)
                    .frame(width: 250, height: 250)
                    .background(.background.opacity(0.3))
            }
        }
    }

    struct FooterView: View {
        @Environment(Player.self) private var player

        var body: some View {
            VStack(spacing: 8) {
                ProgressView()

                HStack(alignment: .center) {
                    RepeatView()
                        .offset(x: 10)

                    Spacer()

                    HStack {
                        PreviousView()
                        PauseView()
                        NextView()
                    }

                    Spacer()

                    RandomView()
                        .offset(x: -10)
                }
                .offset(y: -1)
            }
            .frame(height: 80)
            .background(.thinMaterial)
            .cornerRadius(10)
            .shadow(radius: 20)
        }
    }

    struct ProgressView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 220, height: 3)

                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.accent))
                        .frame(
                            width: max(0, (player.status.elapsed ?? 0) / (player.current?.duration ?? 100) * 220) + 4,
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
            .compositingGroup()
            .blendMode(.overlay)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                Task(priority: .userInitiated) {
                    await player.seek((value.location.x / 220) * (player.current?.duration ?? 100))
                }
            })
            .onHover(perform: { value in
                hover = value
            })
            // TODO:
//            .onAppear {
//                player.status.trackElapsed = true
//            }
//            .onDisappear {
//                player.status.trackElapsed = false
//            }
        }
    }

    struct PauseView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: ((player.status.isPlaying ?? false) ? "pause" : "play") + ".circle.fill")
                .font(.system(size: 35))
                .blendMode(.overlay)
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
                .blendMode(.overlay)
                .padding(10)
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
                .blendMode(.overlay)
                .padding(10)
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
                    .foregroundColor(Color(.textColor))
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
            .blendMode(.overlay)
        }
    }

    struct RepeatView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            ZStack {
                Image(systemName: "repeat")
                    .foregroundColor(Color(.textColor))
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
            .blendMode(.overlay)
        }
    }
}
