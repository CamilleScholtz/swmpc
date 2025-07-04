//
//  DetailView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import ButtonKit
import Noise
import SFSafeSymbols
import SwiftUI
#if os(iOS)
    import LNPopupUI
#endif

struct DetailView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator
    @Environment(\.colorScheme) private var colorScheme

    #if os(iOS)
        @Binding var isPopupOpen: Bool
    #endif

    #if os(macOS)
        @State private var isHovering = false
    #endif

    @State private var artwork: PlatformImage?

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
                    ArtworkView(image: artwork, animationDuration: 0.6)
                        .scaledToFit()
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
                        .drawingGroup()

                    ZStack {
                        ArtworkView(image: artwork, animationDuration: 0.6)

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
                    // TODO: Doesn't really work on dark mode.
                    .blendMode(colorScheme == .dark ? .darken : .softLight)
                    .opacity(0.3)

                ArtworkView(image: artwork)
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
                    .onTapGesture {
                        Task(priority: .userInitiated) {
                            guard let song = mpd.status.song, let album = try? await ConnectionManager.command().getAlbum(for: song) else {
                                return
                            }

                            #if os(iOS)
                                if navigator.category != .albums {
                                    navigator.category = .albums
                                }
                            #endif
                            navigator.navigate(to: ContentDestination.album(album))

                            #if os(iOS)
                                isPopupOpen = false
                            #endif
                        }
                    }
            }
            .offset(y: -110)

            VStack {
                Spacer()

                DetailFooterView()
                    .frame(height: 80)
                #if os(iOS)
                    .padding(.horizontal, 30)
                    .offset(y: -60)
                #endif
            }
        }
        #if os(macOS)
        .ignoresSafeArea()
        #elseif os(iOS)
        .popupImage(artwork != nil ? Image(uiImage: artwork!) : Image(systemSymbol: .musicNote))
        .popupTitle(mpd.status.song?.title ?? "No song playing", subtitle: mpd.status.song?.artist ?? "")
        // swiftformat:disable:next trailingClosures
        .popupBarItems({
            ToolbarItemGroup(placement: .popupBar) {
                AsyncButton {
                    try await ConnectionManager.command().pause(mpd.status.isPlaying)
                } label: {
                    ZStack {
                        Circle()
                            .fill(.thinMaterial)
                            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)

                        ZStack {
                            Image(systemSymbol: .pauseFill)
                                .scaleEffect(mpd.status.isPlaying ? 1 : 0.1)
                                .opacity(mpd.status.isPlaying ? 1 : 0.1)
                                .animation(.interactiveSpring(duration: 0.25), value: mpd.status.isPlaying)

                            Image(systemSymbol: .playFill)
                                .scaleEffect(mpd.status.isPlaying ? 0.1 : 1)
                                .opacity(mpd.status.isPlaying ? 0.1 : 1)
                                .animation(.interactiveSpring(duration: 0.25), value: mpd.status.isPlaying)
                        }
                    }
                }
                .asyncButtonStyle(.pulse)
                .styledButton(hoverScale: 1.13)

                AsyncButton {
                    try await ConnectionManager.command().next()
                } label: {
                    Image(systemSymbol: .forwardFill)
                        .foregroundColor(.primary)
                }
                .asyncButtonStyle(.pulse)
            }
        })
        .popupProgress(progress)
        #endif
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                artwork = nil
                return
            }

            artwork = try? await song.artwork()
        }
    }
}
