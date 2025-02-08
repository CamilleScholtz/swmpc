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
                .frame(width: 250 - 30, height: 80)
                .offset(y: showInfo ? -15 : 90)
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
                await updateArtwork()
            }
        }
        .onReceive(didCloseNotification) { _ in
            artwork = nil
        }
        .task(id: mpd.status.song) {
            guard AppDelegate.shared.popover.isShown else {
                return
            }

            await updateArtwork()
        }
        .onChange(of: artwork) { previous, _ in
            updateHeight()

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
                        showInfo = false || !mpd.status.isPlaying
                    }
                }
            } else {
                showInfo = true
            }

            isHovering = value
        }
    }

    private func updateArtwork() async {
        guard let song = mpd.status.song else {
            return
        }

        guard let data = try? await ArtworkManager.shared.get(using: song.url, shouldCache: false) else {
            return
        }
        artwork = NSImage(data: data)
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
        @Environment(\.colorScheme) var colorScheme

        var body: some View {
            VStack(spacing: 8) {
                ProgressView()

                HStack(alignment: .center, spacing: 0) {
                    RepeatView()
                        .offset(x: 10)

                    Spacer()

                    HStack(spacing: 0) {
                        PreviousView()
                        PauseView()
                        NextView()
                    }

                    Spacer()

                    RandomView()
                        .offset(x: -10)
                }
                .frame(width: 250 - 30)
                .offset(y: -4)
            }
            .frame(height: 80)
            .background(.regularMaterial)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.red.opacity(0.2), lineWidth: 0.5)
                    .blendMode(.screen)
            )
            .padding(1)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.green.opacity(0.2), lineWidth: 1)
                    .blendMode(.screen)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: 3, x: 0, y: 2)
            .shadow(radius: 20)
        }
    }

    struct ProgressView: View {
        @Environment(MPD.self) private var mpd

        @State private var isHovering = false

        var body: some View {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .frame(width: 190, height: 3)

                ZStack(alignment: .trailing) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.accent))
                        .frame(
                            width: max(0, (mpd.status.elapsed ?? 0) / (mpd.status.song?.duration ?? 100) * 190) + 4,
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
            .compositingGroup()
            .blendMode(.overlay)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command.seek((value.location.x / 190) * (mpd.status.song?.duration ?? 100))
                }
            })
            .onHover(perform: { value in
                isHovering = value
            })
        }
    }

    struct PauseView: View {
        @Environment(MPD.self) private var mpd

        @State private var isHovering = false

        var body: some View {
            Image(systemName: (mpd.status.isPlaying ? "pause" : "play") + ".circle.fill")
                .font(.system(size: 35))
                .blendMode(.overlay)
                .scaleEffect(isHovering ? 1.2 : 1)
                .animation(.interactiveSpring, value: isHovering)
                .onHover(perform: { value in
                    isHovering = value
                })
                .onTapGesture(perform: {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command.pause(mpd.status.isPlaying)
                    }
                })
        }
    }

    struct PreviousView: View {
        @State private var isHovering = false

        var body: some View {
            Image(systemName: "backward.fill")
                .blendMode(.overlay)
                .padding(10)
                .scaleEffect(isHovering ? 1.2 : 1)
                .animation(.interactiveSpring, value: isHovering)
                .onHover(perform: { value in
                    isHovering = value
                })
                .onTapGesture(perform: {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command.previous()
                    }
                })
        }
    }

    struct NextView: View {
        @State private var isHovering = false

        var body: some View {
            Image(systemName: "forward.fill")
                .blendMode(.overlay)
                .padding(10)
                .scaleEffect(isHovering ? 1.2 : 1)
                .animation(.interactiveSpring, value: isHovering)
                .onHover(perform: { value in
                    isHovering = value
                })
                .onTapGesture(perform: {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command.next()
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
                    .foregroundColor(Color(.textColor))
                    .padding(10)
                    .scaleEffect(isHovering ? 1.2 : 1)
                    .animation(.interactiveSpring, value: isHovering)
                    .onHover(perform: { value in
                        isHovering = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command.random(!(mpd.status.isRandom ?? false))
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

        @State private var isHovering = false

        var body: some View {
            ZStack {
                Image(systemName: "repeat")
                    .foregroundColor(Color(.textColor))
                    .padding(10)
                    .scaleEffect(isHovering ? 1.2 : 1)
                    .animation(.interactiveSpring, value: isHovering)
                    .onHover(perform: { value in
                        isHovering = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command.repeat(!(mpd.status.isRepeat ?? false))
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
