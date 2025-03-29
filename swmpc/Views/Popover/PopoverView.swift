//
//  PopoverView.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SFSafeSymbols
import SwiftUI

struct PopoverView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    @State private var height = Double(250)

    @State private var artwork: NSImage?
    @State private var previousArtwork: NSImage?

    @State private var isBackgroundArtworkTransitioning = false
    @State private var isArtworkTransitioning = false

    @State private var dragOffset: CGSize = .zero

    @State private var isHovering = false
    @State private var showInfo = false

    private let willShowNotification = NotificationCenter.default
        .publisher(for: NSPopover.willShowNotification)
    private let didCloseNotification = NotificationCenter.default
        .publisher(for: NSPopover.didCloseNotification)

    var body: some View {
        ZStack(alignment: .bottom) {
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
                .opacity(0.3)

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
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = value.translation
                            }
                        }
                        .onEnded { value in
                            guard mpd.status.song != nil else {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dragOffset = .zero
                                }

                                return
                            }

                            let threshold: CGFloat = 50
                            let distance = value.translation.width

                            if distance < -threshold {
                                Task(priority: .userInitiated) {
                                    try? await ConnectionManager.command().next()
                                }
                            } else if distance > threshold {
                                Task(priority: .userInitiated) {
                                    try? await ConnectionManager.command().previous()
                                }
                            }

                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = .zero
                            }
                        }
                )
                .offset(x: dragOffset.width)
                .rotationEffect(.degrees(dragOffset.width / 20 * ((dragOffset.height + 25) / 150)))
                .background(.ultraThinMaterial)

            PopoverFooterView()
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
            withAnimation(.spring(duration: 0.5)) {
                isBackgroundArtworkTransitioning = false
            }
            isArtworkTransitioning = true
            withAnimation(.interactiveSpring) {
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
            artwork = nil
            return
        }

        guard let data = try? await ArtworkManager.shared.get(for: song, shouldCache: false) else {
            artwork = nil
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
                Image(systemSymbol: .photo)
                    .font(.system(size: 25))
                    .blendMode(.overlay)
                    .frame(width: 250, height: 250)
                    .background(.background.opacity(0.3))
            }
        }
    }
}
