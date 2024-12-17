//
//  PopoverView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct PopoverView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) var colorScheme

    @State private var height = Double(250)

    @State private var artwork: NSImage?
    @State private var previousArtwork: NSImage?

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
            ArtworkView(image: artwork)
                // TODO:
//                .overlay(
//                    previousArtwork != nil ? AnyView(ArtworkView(image: previousArtwork)
//                        .opacity(isBackgroundArtworkTransitioning ? 1 : 0)) : AnyView(EmptyView())
//                )
                .opacity(0.3)

            ArtworkView(image: artwork)
                // TODO:
//                .overlay(
//                    previousArtwork?.image != nil ? AnyView(ArtworkView(image: previousArtwork!.image)
//                        .opacity(isArtworkTransitioning ? 1 : 0)) : AnyView(EmptyView())
//                )
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
                guard let song = mpd.status.song else {
                    return
                }

                // TODO:
//                await player.setArtwork(for: song)
//                artwork = player.getArtwork(for: song)
            }
            Task {
                // TODO:
                // await mpd.status.trackElapsed()
            }
        }
        .onReceive(didCloseNotification) { _ in
            // mpd.status.trackingTask?.cancel()
        }
        .onChange(of: mpd.status.song) {
            guard let song = mpd.status.song, AppDelegate.shared.popover.isShown else {
                return
            }

            Task(priority: .userInitiated) {
                // TODO:
//                await player.setArtwork(for: song)
//                artwork = player.getArtwork(for: song)

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
                        showInfo = false || !(mpd.status.isPlaying ?? false)
                    }
                }
            } else {
                showInfo = true
            }

            isHovering = value
        }
    }

    private func updateHeight() {
        guard let artwork else {
            height = 250
            return
        }

        height = (Double(artwork.size.height) / Double(artwork.size.width) * 250).rounded(.down)
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
        @Environment(MPD.self) private var mpd

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
        @Environment(MPD.self) private var mpd

        @State private var hover = false

        var body: some View {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 220, height: 3)

                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.accent))
                        .frame(
                            width: max(0, (mpd.status.elapsed ?? 0) / (mpd.status.song?.duration ?? 100) * 220) + 4,
                            height: 3
                        )

                    Circle()
                        .fill(Color(.accent))
                        .frame(width: 8, height: 8)
                        .scaleEffect(hover ? 1.5 : 1)
                        .animation(.spring, value: hover)
                }
                .animation(.spring, value: mpd.status.elapsed)
            }
            .compositingGroup()
            .blendMode(.overlay)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                Task(priority: .userInitiated) {
                    try? await ConnectionManager().seek((value.location.x / 220) * (mpd.status.song?.duration ?? 100))
                }
            })
            .onHover(perform: { value in
                hover = value
            })
            // TODO:
//            .onAppear {
//                mpd.status.trackElapsed = true
//            }
//            .onDisappear {
//                mpd.status.trackElapsed = false
//            }
        }
    }

    struct PauseView: View {
        @Environment(MPD.self) private var mpd

        @State private var hover = false

        var body: some View {
            Image(systemName: ((mpd.status.isPlaying ?? false) ? "pause" : "play") + ".circle.fill")
                .font(.system(size: 35))
                .blendMode(.overlay)
                .scaleEffect(hover ? 1.2 : 1)
                .animation(.interactiveSpring, value: hover)
                .onHover(perform: { value in
                    hover = value
                })
                .onTapGesture(perform: {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager().pause(mpd.status.isPlaying ?? false)
                    }
                })
        }
    }

    struct PreviousView: View {
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
                        try? await ConnectionManager().previous()
                    }
                })
        }
    }

    struct NextView: View {
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
                        try? await ConnectionManager().next()
                    }
                })
        }
    }

    struct RandomView: View {
        @Environment(MPD.self) private var mpd

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
                            try? await ConnectionManager().random(!(mpd.status.isRandom ?? false))
                        }
                    })

                if mpd.status.isRandom ?? false {
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
        @Environment(MPD.self) private var mpd

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
                            try? await ConnectionManager().repeat(!(mpd.status.isRepeat ?? false))
                        }
                    })

                if mpd.status.isRepeat ?? false {
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
