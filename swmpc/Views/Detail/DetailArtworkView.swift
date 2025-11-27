//
//  DetailArtworkView.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/09/2025.
//

import SwiftUI

struct DetailArtworkView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator
    @Environment(\.colorScheme) private var colorScheme

    let artwork: PlatformImage?

    #if os(macOS)
        @State private var isHovering = false
    #endif

    @State private var colors: [Color]?

    private var artworkHeight: CGFloat {
        artwork.map {
            Double($0.size.height) / Double($0.size.width) * Layout.Size.artworkWidth
        } ?? Layout.Size.artworkWidth
    }

    var body: some View {
        ZStack {
            if let colors {
                ShadowGradientView(colors: colors, artworkHeight: artworkHeight)
                    .opacity(colorScheme == .dark ? 0.3 : 0.8)
            }

            ArtworkView(image: artwork)
                .animation(.easeInOut(duration: 0.3), value: artwork)
                .overlay(
                    Color.clear
                        .glassEffect(.clear, in: .rect(cornerRadius: Layout.CornerRadius.large))
                        .mask(
                            ZStack {
                                RoundedRectangle(cornerRadius: Layout.CornerRadius.large)

                                RoundedRectangle(cornerRadius: Layout.CornerRadius.large)
                                    .scale(0.9)
                                    .blur(radius: 8)
                                    .blendMode(.destinationOut)
                            },
                        ),
                )
                .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.large))
                .frame(width: Layout.Size.artworkWidth)
            #if os(macOS)
                .scaleEffect(isHovering ? 1.02 : 1)
                .animation(.spring, value: isHovering)
                .onHover { value in
                    isHovering = value
                }
            #endif
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
                .onTapGesture {
                    Task(priority: .userInitiated) {
                        guard let song = mpd.status.song else {
                            return
                        }

                        #if os(iOS)
                            if navigator.category != .albums {
                                navigator.category = .albums
                            }
                        #endif

                        navigator.navigate(to: ContentDestination.album(song.album))
                    }
                }
        }
        .task(id: artwork) {
            guard let artwork else {
                colors = nil
                return
            }

            colors = await Color.extractDominantColors(from: artwork, count: 4)
        }
    }
}

private struct ShadowGradientView: View, Equatable {
    let colors: [Color]
    let artworkHeight: CGFloat

    private static let cornerOffsets: [(x: CGFloat, y: CGFloat)] = [
        (-60, -60),
        (60, -60),
        (-60, 60),
        (60, 60),
    ]

    var body: some View {
        ZStack {
            gradientLayer
                .mask(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.large)
                        .frame(width: Layout.Size.artworkWidth + Layout.Padding.small, height: artworkHeight + Layout.Padding.small)
                        .blur(radius: 40),
                )
                .opacity(0.6)

            gradientLayer
                .mask(
                    RadialGradient(
                        colors: [.black, .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: Layout.Size.artworkWidth * 1.4,
                    )
                    .frame(width: Layout.Size.artworkWidth * 2, height: Layout.Size.artworkWidth * 2),
                )
                .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: 0))
                .opacity(0.5)
                .offset(y: artworkHeight / 2)
        }
        .animation(.easeInOut(duration: 0.6), value: colors)
        .drawingGroup()
    }

    private var gradientLayer: some View {
        ZStack {
            ForEach(colors.indices, id: \.self) { index in
                let offset = Self.cornerOffsets[index % 4]

                RadialGradient(
                    colors: [colors[index], .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200,
                )
                .offset(x: offset.x, y: offset.y)
            }
        }
    }

    static func == (lhs: ShadowGradientView, rhs: ShadowGradientView) -> Bool {
        lhs.colors == rhs.colors && lhs.artworkHeight == rhs.artworkHeight
    }
}
