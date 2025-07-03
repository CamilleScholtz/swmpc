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
            ArtworkView(image: artwork, animationDuration: 0.6, aspectRatioMode: .fill)
                .frame(width: 250)
                .opacity(0.3)

            ArtworkView(image: artwork, aspectRatioMode: .fill)
                .frame(width: 250)
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
                    }
                )
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
