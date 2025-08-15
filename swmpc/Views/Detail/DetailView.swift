//
//  DetailView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/11/2024.
//

import ButtonKit

import SFSafeSymbols
import SwiftUI

private extension Layout.Size {
    static let detailControlsHeight: CGFloat = 80
}

struct DetailView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabledSetting = false
    @AppStorage(Setting.intelligenceModel) private var intelligenceModel = IntelligenceModel.openAI

    var isIntelligenceEnabled: Bool {
        guard isIntelligenceEnabledSetting else { return false }
        @AppStorage(intelligenceModel.setting) var token = ""
        return !token.isEmpty
    }

    #if os(macOS)
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

                ArtworkView(image: artwork)
                    .animation(.easeInOut(duration: 0.2), value: artwork)
                    .overlay(
                        Color.clear
                            .glassEffect(.clear, in: .rect(cornerRadius: Layout.CornerRadius.large))
                            .mask(
                                ZStack {
                                    RoundedRectangle(cornerRadius: Layout.CornerRadius.large)

                                    RoundedRectangle(cornerRadius: Layout.CornerRadius.large)
                                        .scale(0.8)
                                        .blur(radius: 8)
                                        .blendMode(.destinationOut)
                                },
                            ),
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.large))
                    .shadow(color: .black.opacity(0.2), radius: 16)
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
                        }
                    }
            }
            .offset(y: -Layout.Size.detailControlsHeight)

            VStack {
                Spacer()

                DetailFooterView()
                    .frame(height: Layout.Size.detailControlsHeight)
            }
            .padding(60)
        }
        .ignoresSafeArea(edges: .vertical)
        #if os(macOS)
            .toolbar {
                ToolbarSpacer(.flexible)

                if showQueuePanel {
                    ToolbarItem {
                        Text("Queue")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .offset(x: -140)
                    }
                    .sharedBackgroundVisibility(.hidden)

                    if !mpd.queue.songs.isEmpty {
                        ToolbarItem {
                            Button(action: {
                                NotificationCenter.default.post(name: .showClearQueueAlertNotification, object: nil)
                            }) {
                                Image(systemSymbol: .trash)
                            }
                            .keyboardShortcut(.delete, modifiers: [.shift, .command])
                            .help("Clear queue")
                        }

                    } else {
                        ToolbarItem {
                            Button(action: {
                                NotificationCenter.default.post(name: .fillIntelligenceQueueNotification, object: nil)
                            }) {
                                Image(systemSymbol: .sparkles)
                            }
                            .disabled(!isIntelligenceEnabled)
                            .help(isIntelligenceEnabled ? "Fill queue with AI" : "AI features are disabled in settings")
                        }
                    }

                    ToolbarSpacer(.fixed)
                }

                ToolbarItem {
                    Button(action: {
                        withAnimation(.spring) {
                            showQueuePanel.toggle()
                        }
                    }) {
                        Image(systemSymbol: showQueuePanel ? .chevronRight : .musicNoteList)
                    }
                    .help(showQueuePanel ? "Hide queue panel" : "Show queue panel")
                }
            }
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
