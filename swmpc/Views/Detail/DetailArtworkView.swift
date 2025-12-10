//
//  DetailArtworkView.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/09/2025.
//

import MPDKit
import SwiftUI

struct DetailArtworkView: View, Equatable {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator
    @Environment(\.colorScheme) private var colorScheme

    let artwork: Artwork?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.artwork == rhs.artwork
    }

    #if os(macOS)
        @State private var isHovering = false
    #endif

    var body: some View {
        ZStack {
            ShadowGradientView(artwork: artwork)
                .opacity(colorScheme == .dark ? 0.4 : 0.8)

            ArtworkView(image: artwork?.image)
                .animation(.easeInOut(duration: 0.3), value: artwork)
                .frame(width: Layout.Size.artworkWidth)
                .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.large))
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
    }

    private struct ShadowGradientView: View {
        let artwork: Artwork?

        @State private var colors: [Color]?

        private static let cornerOffset = Layout.Size.artworkWidth / 4
        private static let cornerOffsets: [(x: CGFloat, y: CGFloat)] = [
            (-cornerOffset, -cornerOffset),
            (cornerOffset, -cornerOffset),
            (-cornerOffset, cornerOffset),
            (cornerOffset, cornerOffset),
        ]

        private var artworkHeight: CGFloat {
            artwork?.image.map {
                Double($0.size.height) / Double($0.size.width) * Layout.Size.artworkWidth
            } ?? Layout.Size.artworkWidth
        }

        var body: some View {
            ZStack {
                if let colors {
                    gradientLayer(colors: colors)
                        .mask(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.large)
                            #if os(iOS)
                                .frame(width: Layout.Size.artworkWidth * 2, height: artworkHeight * 2)
                            #elseif os(macOS)
                                .frame(width: Layout.Size.artworkWidth + Layout.Padding.large, height: artworkHeight + Layout.Padding.large)
                            #endif
                                .blur(radius: 40),
                        )
                    #if os(iOS)
                        .blur(radius: 10)
                    #endif
                        .opacity(0.6)

                    gradientLayer(colors: colors)
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
            }
            #if os(iOS)
            .offset(y: -Layout.Padding.large)
            #endif
            .animation(.easeInOut(duration: 0.6), value: colors)
            .task(id: artwork) {
                guard let image = artwork?.image else {
                    colors = nil
                    return
                }

                colors = await Color.extractDominantColors(from: image, count: 4)
            }
        }

        private func gradientLayer(colors: [Color]) -> some View {
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
    }
}
