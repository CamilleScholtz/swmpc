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

    @AppStorage(Setting.runAsAgent) var runAsAgent = false

    @State private var artwork: PlatformImage?
    @State private var height = Double(250)

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
                .frame(width: 250)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.clear)
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
                .cornerRadius(20)
                .scaleEffect(showInfo ? 0.7 : 1)
                .offset(y: showInfo ? -7 : 0)
                .animation(.spring(response: 0.7, dampingFraction: 1, blendDuration: 0.7), value: showInfo)
                .swipeActions(
                    onSwipeLeft: {
                        guard mpd.status.song != nil else {
                            return
                        }

                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command().next()
                        }
                    },
                    onSwipeRight: {
                        guard mpd.status.song != nil else {
                            return
                        }

                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command().previous()
                        }
                    },
                )

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
                endRadius: 55,
            )
            .offset(x: 23)
            .scaleEffect(x: 1.5),
        )
        .frame(width: 250, height: height)
        .overlay(alignment: .topLeading) {
            if runAsAgent {
                Button {
                    openSettings()
                } label: {
                    Image(systemSymbol: .gearshapeFill)
                        .foregroundColor(Color(.tertiaryLabelColor))
                        .font(.system(size: 14))
                        .padding(8)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .opacity(showInfo ? 1 : 0)
                .animation(.spring, value: showInfo)
            }
        }
        .onReceive(willShowNotification) { _ in
            Task(priority: .userInitiated) {
                guard let song = mpd.status.song else {
                    artwork = nil
                    height = 250
                    return
                }

                artwork = try? await song.artwork()
                guard let artwork else {
                    height = 250
                    return
                }

                height = (Double(artwork.size.height) / Double(artwork.size.width) * 250).rounded(.down)

                try? await mpd.status.startTrackingElapsed()
            }
        }
        .onReceive(didCloseNotification) { _ in
            mpd.status.stopTrackingElapsed()
        }
        .task(id: mpd.status.song) {
            guard AppDelegate.shared.popover.isShown else {
                return
            }

            guard let song = mpd.status.song else {
                artwork = nil
                height = 250
                return
            }

            artwork = try? await song.artwork()
            guard let artwork else {
                height = 250
                return
            }

            height = (Double(artwork.size.height) / Double(artwork.size.width) * 250).rounded(.down)
        }
        .onHoverWithDebounce(delay: .milliseconds(100), handler: hoverHandler) { hovering in
            isHovering = hovering
            if hovering {
                showInfo = true
            } else {
                showInfo = false || !mpd.status.isPlaying
            }
        }
    }
}
