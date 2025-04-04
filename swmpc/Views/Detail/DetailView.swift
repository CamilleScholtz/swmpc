//
//  DetailView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import Noise
import SFSafeSymbols
import SwiftUI

#if os(iOS)
    import LNPopupUI
#endif

struct DetailView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator
    @Environment(\.colorScheme) private var colorScheme

    #if os(iOS)
        let artwork: UIImage?
        @Binding var isPopupOpen: Bool

        @State private var previousArtwork: UIImage?
    #elseif os(macOS)
        let artwork: NSImage?

        @State private var previousArtwork: NSImage?
    #endif

    @State private var isBackgroundArtworkTransitioning = false
    @State private var isArtworkTransitioning = false

    @State private var dragOffset: CGSize = .zero

    #if os(macOS)
        @State private var isHovering = false
    #endif

    #if os(iOS)
        private var progress: Float {
            guard let elapsed = mpd.status.elapsed,
                  let duration = mpd.status.song?.duration,
                  duration > 0
            else {
                return 0
            }

            return Float(elapsed / duration)
        }
    #endif

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
                    .drawingGroup()
                    #if os(iOS)
                        .mask(
                            RadialGradient(
                                gradient: Gradient(colors: [.white, .clear]),
                                center: .center,
                                startRadius: -15,
                                endRadius: 275
                            )
                        )
                    #elseif os(macOS)
                        .mask(
                            RadialGradient(
                                gradient: Gradient(colors: [.white, .clear]),
                                center: .center,
                                startRadius: -15,
                                endRadius: 225
                            )
                        )
                    #endif
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
                    .drawingGroup()
                    #if os(iOS)
                        .mask(
                            RadialGradient(
                                gradient: Gradient(colors: [.white, .clear]),
                                center: .center,
                                startRadius: -25,
                                endRadius: 200
                            )
                        )
                        .scaleEffect(1.3)
                    #elseif os(macOS)
                        .mask(
                            RadialGradient(
                                gradient: Gradient(colors: [.white, .clear]),
                                center: .center,
                                startRadius: -25,
                                endRadius: 225
                            )
                        )
                    #endif
                        .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: 0))
                        .offset(y: 105)
                        .blur(radius: 5)
                }
                .saturation(1.5)
                .blendMode(colorScheme == .dark ? .softLight : .normal)
                #if os(iOS)
                    .opacity(isPopupOpen ? 1 : 0)
                    .animation(.spring.delay(isPopupOpen ? 0.2 : 0), value: isPopupOpen)
                #endif

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
                #if os(iOS)
                    .frame(width: 300)
                    .popupTransitionTarget()
                #elseif os(macOS)
                    .frame(width: 250)
                    .scaleEffect(isHovering ? 1.02 : 1)
                    .animation(.spring, value: isHovering)
                    .onHover(perform: { value in
                        isHovering = value
                    })
                #endif
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

                DetailFooterView()
                    .frame(height: 80)
                #if os(iOS)
                    .padding(.horizontal, 30)
                #endif
            }
        }
        #if os(macOS)
        .ignoresSafeArea()
        #endif
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
        #if os(iOS)
        .popupImage((artwork != nil) ? Image(uiImage: artwork!) : Image(systemSymbol: .musicNote))
        .popupTitle(mpd.status.song?.title ?? "No song playing", subtitle: mpd.status.song?.artist ?? "")
        // swiftformat:disable:next trailingClosures
        .popupBarItems({
            ToolbarItemGroup(placement: .popupBar) {
                Button {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().pause(mpd.status.isPlaying)
                    }
                } label: {
                    Image(systemSymbol: mpd.status.isPlaying ? .pauseFill : .playFill)
                }

                Button {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().next()
                    }
                } label: {
                    Image(systemSymbol: .forwardFill)
                }
            }
        })
        .popupProgress(progress)
        #endif
    }

    struct ArtworkView: View {
        #if os(iOS)
            let image: UIImage?
        #elseif os(macOS)
            let image: NSImage?
        #endif

        var body: some View {
            ZStack {
                if let image {
                    #if os(iOS)
                        Image(uiImage: image)
                            .resizable()
                    #elseif os(macOS)
                        Image(nsImage: image)
                            .resizable()
                    #endif
                } else {
                    Color(.secondarySystemFill)
                }
            }
            .transition(.opacity.animation(.spring))
            .aspectRatio(contentMode: .fit)
        }
    }
}
