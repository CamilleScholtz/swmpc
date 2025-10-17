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

    let artwork: PlatformImage?

    #if os(macOS)
        @Binding var showQueuePanel: Bool
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

    #elseif os(macOS)
        private var queueTextWidth: CGFloat {
            String(localized: "Queue").width(withFont: NSFont.systemFont(ofSize: 15, weight: .semibold))
        }
    #endif

    var body: some View {
        ZStack {
            DetailArtworkView(artwork: artwork)
            #if os(iOS)
                .offset(y: -Layout.Size.detailControlsHeight * 1.25)
            #elseif os(macOS)
                .offset(y: -Layout.Size.detailControlsHeight)
            #endif

            VStack {
                Spacer()

                DetailFooterView()
                    .frame(height: Layout.Size.detailControlsHeight)
            }
            #if os(iOS)
            .padding(Layout.Padding.large)
            #elseif os(macOS)
            .padding(Layout.Padding.large * 4)
            #endif
        }
        #if os(macOS)
        .ignoresSafeArea(edges: .vertical)
        .toolbar {
            ToolbarSpacer(.flexible)

            if showQueuePanel {
                ToolbarItem {
                    Text("Queue")
                        .font(.system(size: 15))
                        .fontWeight(.semibold)
                        .offset(x: queueTextWidth - 148)
                }
                .sharedBackgroundVisibility(.hidden)

                ToolbarItem {
                    AsyncButton(mpd.status.isConsume ?? false ? "Disable Consume" : "Enable Consume", systemImage: mpd.status.isConsume ?? false ? SFSymbol.flameFill.rawValue : SFSymbol.flame.rawValue) {
                        try await ConnectionManager.command {
                            try await $0.consume(!(mpd.status.isConsume ?? false))
                        }
                    }
                }

                if !mpd.queue.songs.isEmpty {
                    ToolbarItem {
                        Button("Clear Queue", systemSymbol: .trash, role: .destructive) {
                            NotificationCenter.default.post(name: .showClearQueueAlertNotification, object: nil)
                        }
                        .keyboardShortcut(.delete, modifiers: [.shift, .command])
                    }

                } else {
                    ToolbarItem {
                        Button("Fill Queue with AI", systemSymbol: .sparkles) {
                            NotificationCenter.default.post(name: .fillIntelligenceQueueNotification, object: nil)
                        }
                        .disabled(!IntelligenceManager.isEnabled)
                    }
                }

                ToolbarSpacer(.fixed)
            }

            ToolbarItem {
                Button(showQueuePanel ? "Hide Queue" : "Show Queue", systemSymbol: showQueuePanel ? .chevronRight : .musicNoteList) {
                    withAnimation(.spring) {
                        showQueuePanel.toggle()
                    }
                }
            }
        }
        #endif
    }
}
