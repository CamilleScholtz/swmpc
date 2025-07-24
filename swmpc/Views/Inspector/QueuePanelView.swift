//
//  QueuePanelView.swift
//  swmpc
//
//  Created by Camille Scholtz on 06/02/2025.
//

import ButtonKit
import SwiftUI
import SwiftUIIntrospect

struct QueuePanelView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage(Setting.isIntelligenceEnabled) private var isIntelligenceEnabled = false

    @Binding var showQueuePanel: Bool

    @State private var showClearQueueAlert = false
    @State private var showIntelligenceQueueSheet = false

    private let fillIntelligenceQueueNotification = NotificationCenter.default
        .publisher(for: .fillIntelligenceQueueNotification)

    var body: some View {
        VStack(spacing: 0) {
            if mpd.queue.songs.isEmpty {
                EmptyQueueView()
            } else {
                QueueView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Spacer()
                Spacer()

                if showQueuePanel {
                    if mpd.queue.songs.isEmpty, isIntelligenceEnabled {
                        Button(action: {
                            NotificationCenter.default.post(name: .fillIntelligenceQueueNotification, object: nil)
                        }) {
                            Image(systemSymbol: .sparkles)
                                .frame(width: 22, height: 22)
                                .foregroundColor(.primary)
                                .padding(4)
                                .contentShape(Circle())
                        }
                        .styledButton()
                    } else if !mpd.queue.songs.isEmpty {
                        Button(action: {
                            // showClearQueueAlert = true
                        }) {
                            Image(systemSymbol: .trash)
                                .frame(width: 22, height: 22)
                                .foregroundColor(.primary)
                                .padding(4)
                                .contentShape(Circle())
                        }
                        .styledButton()
                        .keyboardShortcut(.delete, modifiers: [.shift, .command])
                    }
                }
            }
        }
        .alert("Clear Queue", isPresented: $showClearQueueAlert) {
            Button("Cancel", role: .cancel) {}

            AsyncButton("Clear Queue", role: .destructive) {
                try await ConnectionManager.command().clearQueue()
            }
        } message: {
            Text("This will remove all songs from the queue.")
        }
        .onReceive(fillIntelligenceQueueNotification) { _ in
            showIntelligenceQueueSheet = true
        }
        .sheet(isPresented: $showIntelligenceQueueSheet) {
            IntelligenceView(target: .queue, showSheet: $showIntelligenceQueueSheet)
        }
    }

    struct EmptyQueueView: View {
        var body: some View {
            VStack(spacing: 10) {
                Text("Queue is empty")
                    .font(.headline)
                Text("Add songs from the library to play them")
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    struct QueueView: View {
        @Environment(MPD.self) private var mpd
        @Environment(\.colorScheme) private var colorScheme

        private var songs: [Song] {
            mpd.queue.songs
        }

        #if os(iOS)
            @State private var scrollView: UIScrollView?
        #elseif os(macOS)
            @State private var scrollView: NSScrollView?
        #endif

        var body: some View {
            List {
                MediaView(using: mpd.queue)
            }
            .listStyle(.plain)
            .scrollEdgeEffectStyle(.soft, for: .top)
            #if os(iOS)
                .introspect(.list, on: .iOS(.v26)) { _ in
                    DispatchQueue.main.async {
                        // scrollView = collectionView.enclosingScrollView
                    }
                }
            #elseif os(macOS)
                .introspect(.list, on: .macOS(.v26)) { tableView in
                    DispatchQueue.main.async {
                        scrollView = tableView.enclosingScrollView
                    }
                }
            #endif
                .safeAreaPadding(.bottom, 7.5)
                .contentMargins(.vertical, -7.5, for: .scrollIndicators)
                .onChange(of: scrollView) {
                    try? scrollToCurrent(animate: false)
                }
                .environment(\.defaultMinListRowHeight, min(31.5 + 15, 50))
        }

        private func scrollToCurrent(animate: Bool = true) throws {
            guard let scrollView,
                  let song = mpd.status.song,
                  let index = mpd.queue.songs.firstIndex(where: {
                      $0.url == song.url
                  })
            else {
                throw ViewError.missingData
            }

            #if os(iOS)
            //                let rowSpacing: CGFloat = 15
            //                let baseRowHeight: CGFloat = switch destination {
            //                case .albums, .artists: 50
            //                case .songs, .playlist, _: 31.5
            //                }
            //                let rowHeight = baseRowHeight + rowSpacing
            //
            //                let rowMidY = (CGFloat(currentIndex) * rowHeight) + (rowHeight / 2)
            //                let visibleHeight = scrollView.frame.height
            //                let centeredOffset = rowMidY - (visibleHeight / 2)
            //
            //                scrollView.setContentOffset(
            //                    CGPoint(x: 0, y: max(0, centeredOffset)),
            //                    animated: animate
            //                )
            #elseif os(macOS)
                guard let tableView = scrollView.documentView as? NSTableView else {
                    throw ViewError.missingData
                }

                tableView.layoutSubtreeIfNeeded()
                scrollView.layoutSubtreeIfNeeded()

                DispatchQueue.main.async {
                    let rect = tableView.frameOfCell(atColumn: 0, row: index)
                    let y = rect.midY - (scrollView.frame.height / 2)
                    let center = NSPoint(x: 0, y: max(0, y))

                    if animate {
                        scrollView.contentView.animator().setBoundsOrigin(center)
                    } else {
                        scrollView.contentView.setBoundsOrigin(center)
                    }
                }
            #endif
        }
    }
}
