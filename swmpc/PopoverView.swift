//
//  PopoverView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct PopoverView: View {
    @Environment(Player.self) private var player

    @State private var height = Double(250)

    @State private var artwork: Artwork?
    @State private var previousArtwork: Artwork?

    @State private var isBackgroundArtworkTransitioning = false
    @State private var isArtworkTransitioning = false

    @State private var isHovering = false
    @State private var showInfo = false

    @State private var cursorMonitor: Any?
    @State private var cursorPosition: CGPoint = .zero

    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0

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
                .opacity(0.3)

            ArtworkView(image: artwork?.image)
                .overlay(
                    previousArtwork?.image != nil ? AnyView(ArtworkView(image: previousArtwork!.image)
                        .opacity(isArtworkTransitioning ? 1 : 0)) : AnyView(EmptyView())
                )
                .cornerRadius(10)
                .rotation3DEffect(
                    Angle(degrees: rotationX),
                    axis: (x: 1.0, y: 0.0, z: 0.0)
                )
                .rotation3DEffect(
                    Angle(degrees: rotationY),
                    axis: (x: 0.0, y: 1.0, z: 0.0)
                )
                .animation(.spring, value: rotationX)
                .animation(.spring, value: rotationY)
                .scaleEffect(showInfo ? 0.7 : 1)
                .offset(y: showInfo ? -7 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 1, blendDuration: 0.7), value: showInfo)
                .shadow(color: .black.opacity(0.2), radius: 16)
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

                await player.setArtwork(for: current.id)
                artwork = player.getArtwork(for: current.id)
            }
            Task {
               // await player.status.trackElapsed()
            }

            setupCursorMonitor()
        }
        .onReceive(didCloseNotification) { _ in
            //player.status.trackingTask?.cancel()

            removeCursorMonitor()
        }
        .onChange(of: player.current) {
            guard let current = player.current, AppDelegate.shared.popover.isShown else {
                return
            }

            Task(priority: .userInitiated) {
                await player.setArtwork(for: current.id)
                artwork = player.getArtwork(for: current.id)

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

            if !value {
                rotationX = 0
                rotationY = 0
            }
        }
    }

    private func setupCursorMonitor() {
        var lastFireTime: DispatchTime = .now()
        let debounceInterval: TimeInterval = 0.05

        cursorMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            let now = DispatchTime.now()

            guard now > lastFireTime + debounceInterval, isHovering else {
                return event
            }

            var location = event.locationInWindow

            if event.window == nil {
                guard let frame = NSApp.keyWindow?.frame else {
                    return event
                }

                location = CGPoint(
                    x: location.x - frame.origin.x,
                    y: location.y - frame.origin.y
                )
            }

            let xPercentage = Double(location.x / 250)
            let yPercentage = Double(location.y / height)

            rotationX = (yPercentage - 0.5) * -8
            rotationY = (xPercentage - 0.5) * 8

            lastFireTime = now

            return event
        }
    }

    private func removeCursorMonitor() {
        guard let monitor = cursorMonitor else {
            return
        }

        NSEvent.removeMonitor(monitor)
        cursorMonitor = nil
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
            ZStack(alignment: .top) {
                ProgressView()

                VStack(spacing: 0) {
                    Spacer()

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

                    Spacer()
                }
                .offset(y: 2)
            }
            .frame(height: 80)
            .background(.ultraThinMaterial)
        }
    }

    struct ProgressView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(.textColor))
                        .frame(
                            width: (player.status.elapsed ?? 0) / (player.current?.duration ?? 100) * 250,
                            height: hover ? 8 : 4
                        )
                        .animation(.spring, value: player.status.elapsed)

                    Rectangle()
                        .fill(Color(.textBackgroundColor))
                        .frame(
                            width: Double.maximum(0, 250 - ((player.status.elapsed ?? 0) / (player.current?.duration ?? 100) * 250)),
                            height: hover ? 8 : 4
                        )
                        .animation(.spring, value: player.status.elapsed)
                }
                .blendMode(.softLight)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    Task(priority: .userInitiated) {
                        await player.seek((value.location.x / 250) * (player.current?.duration ?? 100))
                    }
                })

                HStack(alignment: .center) {
                    Text(player.status.elapsed?.timeString ?? "-:--")
                        .font(.system(size: 10))
                        .blendMode(.overlay)
                        .offset(x: 5, y: 3)

                    Spacer()

                    Text(player.current?.duration?.timeString ?? "-:--")
                        .font(.system(size: 10))
                        .blendMode(.overlay)
                        .offset(x: -5, y: 3)
                }
            }
            .animation(.interactiveSpring, value: hover)
            .onHover(perform: { value in
                hover = value
            })
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
            Image(systemName: "shuffle")
                .foregroundColor(Color(player.status.isRandom ?? false ? .textBackgroundColor : .textColor))
                .blendMode(.overlay)
                .animation(.interactiveSpring, value: player.status.isRandom)
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
        }
    }

    struct RepeatView: View {
        @Environment(Player.self) private var player

        @State private var hover = false

        var body: some View {
            Image(systemName: "repeat")
                .foregroundColor(Color(player.status.isRepeat ?? false ? .textBackgroundColor : .textColor))
                .blendMode(.overlay)
                .animation(.interactiveSpring, value: player.status.isRepeat)
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
        }
    }
}
