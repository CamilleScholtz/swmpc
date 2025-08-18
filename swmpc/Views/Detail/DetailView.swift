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
    @State private var selectedVersion: Color.ExtractionVersion = .kMeansClustering

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

    @ViewBuilder
    private func shadowGradient(colors: [Color]) -> some View {
        let cornerOffsets: [(x: CGFloat, y: CGFloat)] = [
            (-60, -60),
            (60, -60),
            (-60, 60),
            (60, 60)
        ]
        
        ZStack {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
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
    }
    
    var body: some View {
        ZStack {
            VStack {
                HStack(spacing: 12) {
                    Button(action: {
                        selectedVersion = .kMeansClustering
                    }) {
                        Text("1")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 30, height: 30)
                            .background(selectedVersion == .kMeansClustering ? Color.accentColor : Color.gray.opacity(0.3))
                            .foregroundColor(selectedVersion == .kMeansClustering ? .white : .primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        selectedVersion = .histogramQuantization
                    }) {
                        Text("2")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 30, height: 30)
                            .background(selectedVersion == .histogramQuantization ? Color.accentColor : Color.gray.opacity(0.3))
                            .foregroundColor(selectedVersion == .histogramQuantization ? .white : .primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        selectedVersion = .labColorSpace
                    }) {
                        Text("3")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 30, height: 30)
                            .background(selectedVersion == .labColorSpace ? Color.accentColor : Color.gray.opacity(0.3))
                            .foregroundColor(selectedVersion == .labColorSpace ? .white : .primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        selectedVersion = .gridSampling
                    }) {
                        Text("4")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 30, height: 30)
                            .background(selectedVersion == .gridSampling ? Color.accentColor : Color.gray.opacity(0.3))
                            .foregroundColor(selectedVersion == .gridSampling ? .white : .primary)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .offset(y: 80)
            .zIndex(1000)
            
            ZStack {
                if let colors {
                    ZStack {
                        let height = artwork.map {
                            Double($0.size.height) / Double($0.size.width) * Layout.Size.artworkWidth
                        } ?? Layout.Size.artworkWidth
                        
                        shadowGradient(colors: colors)
                            .mask(
                                RoundedRectangle(cornerRadius: Layout.CornerRadius.large)
                                    .frame(width: Layout.Size.artworkWidth + 15, height: height + 15)
                                    .blur(radius: 40)
                            )
                            .opacity(0.6)
                        
                        shadowGradient(colors: colors)
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
                            .animation(.easeInOut(duration: 0.6), value: colors)
                    }
                    .blendMode(colorScheme == .dark ? .softLight : .normal)
                    .brightness(-0.3)
                    .saturation(0.9)
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
                
                colors = await Color.extractDominantColors(from: artwork, count: 4, version: selectedVersion)
            }
            .task(id: selectedVersion) {
                guard let artwork else { return }
                colors = await Color.extractDominantColors(from: artwork, count: 4, version: selectedVersion)
            }
    }
}
