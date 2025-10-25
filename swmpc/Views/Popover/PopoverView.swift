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
    @Environment(\.openSettings) private var openSettings

    @State private var artwork: PlatformImage?
    @State private var height = Double(Layout.Size.artworkWidth)

    @State private var isHovering = false
    @State private var showInfo = false
    @State private var hoverHandler = HoverTaskHandler()

    private let willShowNotification = NotificationCenter.default
        .publisher(for: NSPopover.willShowNotification)
    private let didCloseNotification = NotificationCenter.default
        .publisher(for: NSPopover.didCloseNotification)

    var body: some View {
        ZStack(alignment: .bottom) {
            ArtworkView(image: artwork, aspectRatioMode: .fill)
                .animation(.easeInOut(duration: 0.2), value: artwork)
                .frame(width: Layout.Size.artworkWidth)
                .overlay(
                    Color.clear
                        .glassEffect(.clear, in: .rect(cornerRadius: 20))
                        .mask(
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)

                                RoundedRectangle(cornerRadius: 20)
                                    .scale(0.8)
                                    .blur(radius: 8)
                                    .blendMode(.destinationOut)
                            },
                        ),
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .scaleEffect(showInfo ? 0.7 : 1)
                .offset(y: showInfo ? -7 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 1, blendDuration: 0.7), value: showInfo)
                .swipeActions(
                    onSwipeLeft: {
                        guard mpd.status.song != nil else {
                            return
                        }

                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command {
                                try await $0.next()
                            }
                        }
                    },
                    onSwipeRight: {
                        guard mpd.status.song != nil else {
                            return
                        }

                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command {
                                try await $0.previous()
                            }
                        }
                    },
                )

            PopoverFooterView()
                .frame(width: Layout.Size.popoverContentWidth, height: Layout.Size.popoverFooterHeight)
                .offset(y: showInfo ? -Layout.Padding.large : 90)
                .animation(.spring, value: showInfo)
        }
        .mask(
            RadialGradient(
                gradient: Gradient(colors: [.clear, .white]),
                center: .top,
                startRadius: 5,
                endRadius: showInfo ? 6 : 55,
            )
            .offset(x: 23)
            .scaleEffect(x: 1.5)
            .animation(.spring, value: showInfo),
        )
        .frame(width: Layout.Size.artworkWidth, height: height)
        .onReceive(willShowNotification) { _ in
            Task(priority: .userInitiated) {
                guard let song = mpd.status.song else {
                    artwork = nil
                    height = Layout.Size.artworkWidth
                    return
                }

                artwork = try? await song.artwork()
                guard let artwork else {
                    height = Layout.Size.artworkWidth
                    return
                }

                height = (Double(artwork.size.height) / Double(artwork.size.width) * Layout.Size.artworkWidth).rounded(.down)

                try? await mpd.status.startTrackingElapsed()
            }
        }
        .onReceive(didCloseNotification) { _ in
            mpd.status.stopTrackingElapsed()
        }
        .task(id: mpd.status.song) {
            guard AppDelegate.shared?.popover.isShown == true else {
                return
            }

            guard let song = mpd.status.song else {
                artwork = nil
                height = Layout.Size.artworkWidth
                return
            }

            artwork = try? await song.artwork()
            guard let artwork else {
                height = Layout.Size.artworkWidth
                return
            }

            height = (Double(artwork.size.height) / Double(artwork.size.width) * Layout.Size.artworkWidth).rounded(.down)
        }
        .onHoverWithDebounce(delay: .milliseconds(100), handler: hoverHandler) { value in
            isHovering = value

            if value {
                showInfo = true
            } else {
                showInfo = false || !mpd.status.isPlaying
            }
        }
    }
}
