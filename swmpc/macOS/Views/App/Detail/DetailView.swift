//
//  DetailView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import Noise
import SFSafeSymbols
import SwiftUI

struct DetailView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator
    @Environment(\.colorScheme) private var colorScheme

    @State private var artwork: NSImage?
    @State private var previousArtwork: NSImage?

    @State private var isBackgroundArtworkTransitioning = false
    @State private var isArtworkTransitioning = false

    @State private var isHovering = false

    var body: some View {
        ZStack {
            ZStack {
                ZStack {
                    ZStack {
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

                        Rectangle()
                            .opacity(0)
                            .background(.ultraThinMaterial)
                    }
                    .scaledToFit()
                    .mask(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .clear]),
                            center: .center,
                            startRadius: -15,
                            endRadius: 225
                        )
                    )
                    .offset(y: 20)
                    .blur(radius: 20)
                    .opacity(0.6)

                    ZStack {
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

                        Rectangle()
                            .opacity(0)
                            .background(.ultraThinMaterial)
                    }
                    .scaledToFit()
                    .mask(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .clear]),
                            center: .center,
                            startRadius: -25,
                            endRadius: 225
                        )
                    )
                    .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: 0))
                    .offset(y: 105)
                    .blur(radius: 5)
                }
                .saturation(1.5)
                .blendMode(colorScheme == .dark ? .softLight : .normal)

                Noise(style: .random)
                    .monochrome()
                    .blur(radius: 0.2)
                    // TODO: Doesn't really work on dark mode.
                    .blendMode(colorScheme == .dark ? .darken : .softLight)
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
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(colorScheme == .dark ? 0.4 : 0.6), .clear],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                                .blendMode(.screen)

                            RoundedRectangle(cornerRadius: 20)
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
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.2), radius: 16)
                    .frame(width: 250)
                    .scaleEffect(isHovering ? 1.02 : 1)
                    .animation(.spring, value: isHovering)
                    .onHover(perform: { value in
                        isHovering = value
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            guard let song = mpd.status.song else {
                                return
                            }

                            guard let album = try? await mpd.queue.get(for: song, using: .album) as? Album else {
                                return
                            }

                            guard let navigator = navigator.root.child(named: "content") else {
                                return
                            }

                            // TODO: Check if top of stack is same album.
                            navigator.navigate(to: ContentDestination.album(album))
                        }
                    })
            }
            .offset(y: -110)

            VStack {
                Spacer()

                FooterView()
                    .frame(height: 80)
            }
        }
        .ignoresSafeArea()
        .task(id: mpd.status.song) {
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
        .onChange(of: artwork) { previous, _ in
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
    }

    struct ArtworkView: View {
        let image: NSImage?

        var body: some View {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                } else {
                    Color(.secondarySystemFill)
                }
            }
            .transition(.opacity.animation(.spring))
            .aspectRatio(contentMode: .fit)
        }
    }
}
