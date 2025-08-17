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
    @State private var colors: [Color]?

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
                if let colors {
                    let height = artwork.map {
                        Double($0.size.height) / Double($0.size.width) * Layout.Size.artworkWidth
                    } ?? Layout.Size.artworkWidth
                    
                    ZStack {
                        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                            let cornerOffsets: [(x: CGFloat, y: CGFloat)] = [
                                (-60, -60),  // Top left
                                (60, -60),   // Top right
                                (-60, 60),   // Bottom left
                                (60, 60)     // Bottom right
                            ]
                            let offset = cornerOffsets[index % 4]
                            
                            RadialGradient(
                                colors: [color, .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                            .offset(
                                x: offset.x,
                                y: offset.y
                            )
                        }
                    }
                    .mask(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.large)
                            .frame(width: Layout.Size.artworkWidth + 20, height: height + 20)
                            .blur(radius: 40)
                    )
                    .opacity(0.8)

    
                    ZStack {
                        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                            let cornerOffsets: [(x: CGFloat, y: CGFloat)] = [
                                (-60, -60),  // Top left
                                (60, -60),   // Top right
                                (-60, 60),   // Bottom left
                                (60, 60)     // Bottom right
                            ]
                            let offset = cornerOffsets[index % 4]
                            
                            RadialGradient(
                                colors: [color, .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                            .offset(
                                x: offset.x,
                                y: offset.y
                            )
                        }
                    }
                    .mask(
                        RadialGradient(
                            colors: [.black, .clear],
                            center: .center,
                            startRadius: Layout.Size.artworkWidth * 0.2,
                            endRadius: Layout.Size.artworkWidth,
                        ),
                    )
                    .rotation3DEffect(.degrees(75), axis: (x: 1, y: 0, z: 0))
                    .opacity(0.5)
                    .offset(y: height / 2)
                    .blendMode(colorScheme == .dark ? .softLight : .normal)
                    .animation(.easeInOut(duration: 0.6), value: colors)
                }
                
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
                    colors = nil
    
                    return
                }

                artwork = try? await song.artwork()
                guard let artwork else {
                    colors = nil
                    
                    return
                }
                
                colors = await Color.extractDominantColors(from: artwork, count: 4).shuffled()
            }
    }
}
