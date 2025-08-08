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

struct DetailView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabled = false

    #if os(iOS)
        @Binding var isPopupOpen: Bool
    #elseif os(macOS)
        @Binding var showQueuePanel: Bool
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
                    ArtworkView(image: artwork)
                        .scaledToFit()
                        .animation(.easeInOut(duration: 0.6), value: artwork)
                    #if os(iOS)
                        .mask(
                            RadialGradient(
                                gradient: Gradient(colors: [.white, .clear]),
                                center: .center,
                                startRadius: -15,
                                endRadius: 275,
                            ),
                        )
                    #elseif os(macOS)
                        .mask(
                            RadialGradient(
                                gradient: Gradient(colors: [.white, .clear]),
                                center: .center,
                                startRadius: -15,
                                endRadius: 225,
                            )
                            .ignoresSafeArea(.all),
                        )
                    #endif
                        .offset(y: 20)
                        .blur(radius: 20)
                        .opacity(0.6)
                        .drawingGroup()

                    ZStack {
                        ArtworkView(image: artwork)
                            .animation(.easeInOut(duration: 0.6), value: artwork)

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
                                endRadius: 200,
                            ),
                        )
                        .scaleEffect(1.3)
                    #elseif os(macOS)
                        .mask(
                            RadialGradient(
                                gradient: Gradient(colors: [.white, .clear]),
                                center: .center,
                                startRadius: -25,
                                endRadius: 225,
                            ),
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
                    .opacity(colorScheme == .dark ? 0.1 : 0.3)

                ArtworkView(image: artwork)
                    .animation(.easeInOut(duration: 0.2), value: artwork)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(.clear)
                            .glassEffect(.clear, in: .rect(cornerRadius: 30))
                            .mask(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 30)

                                    RoundedRectangle(cornerRadius: 30)
                                        .scale(0.8)
                                        .blur(radius: 8)
                                        .blendMode(.destinationOut)
                                },
                            ),
                    )
                    .cornerRadius(30)
                    .shadow(color: .black.opacity(0.2), radius: 16)
                #if os(iOS)
                    .frame(width: 300)
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

                            #if os(iOS)
                                isPopupOpen = false
                            #endif
                        }
                    }
            }
            .ignoresSafeArea(edges: .vertical)
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
        .toolbar {
            #if os(macOS)
                ToolbarSpacer(.flexible)

                ToolbarItem {
                    Text("Queue")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .offset(x: -140)
                }
                .sharedBackgroundVisibility(.hidden)
                .hidden(!showQueuePanel)

                ToolbarItem {
                    Button(action: {
                        NotificationCenter.default.post(name: .showClearQueueAlertNotification, object: nil)
                    }) {
                        Image(systemSymbol: .trash)
                    }
                    .keyboardShortcut(.delete, modifiers: [.shift, .command])
                }
                .hidden(!showQueuePanel || mpd.queue.songs.isEmpty)

                ToolbarItem {
                    Button(action: {
                        NotificationCenter.default.post(name: .fillIntelligenceQueueNotification, object: nil)
                    }) {
                        Image(systemSymbol: .sparkles)
                    }
                    .disabled(!isIntelligenceEnabled)
                }
                .hidden(!showQueuePanel || !mpd.queue.songs.isEmpty)

                ToolbarSpacer(.fixed)
                    .hidden(!showQueuePanel)

                ToolbarItem {
                    Button(action: {
                        withAnimation(.spring) {
                            showQueuePanel.toggle()
                        }
                    }) {
                        Image(systemSymbol: showQueuePanel ? .chevronRight : .musicNoteList)
                    }
                }
            #endif
        }
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                artwork = nil
                return
            }

            artwork = try? await song.artwork()
        }
    }
}
