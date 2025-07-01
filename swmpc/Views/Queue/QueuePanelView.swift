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
            if mpd.queue.internalMedia.isEmpty {
                EmptyQueueView()
            } else {
                QueueView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 7.5) {
            HStack {
                Text("Queue")
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
                    if mpd.queue.internalMedia.isEmpty, isIntelligenceEnabled {
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
                    } else if !mpd.queue.internalMedia.isEmpty {
                        Button(action: {
                            showClearQueueAlert = true
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

                    Button(role: .cancel, action: {
                        withAnimation(.spring) {
                            showQueuePanel = false
                        }
                    }) {
                        Image(systemSymbol: .xmarkCircleFill)
                            .frame(width: 22, height: 22)
                            .foregroundColor(.primary)
                            .padding(4)
                            .contentShape(Circle())
                    }
                    .styledButton()
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.leading, 15)
            .padding(.trailing, 7.5)
            .frame(height: 50 + 7.5)
            .background(.background)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(colorScheme == .dark ? .black : Color(.secondarySystemFill)),
                alignment: .bottom
            )
            .frame(height: 50 + 7.5 + 1)
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
            mpd.queue.internalMedia as? [Song] ?? []
        }

        #if os(iOS)
            @State private var scrollView: UIScrollView?
        #elseif os(macOS)
            @State private var scrollView: NSScrollView?
        #endif

        var body: some View {
            List {
                MediaView(using: mpd.queue, type: .song)
            }
            .listStyle(.plain)
            .introspect(.list, on: .macOS(.v15)) { tableView in
                DispatchQueue.main.async {
                    scrollView = tableView.enclosingScrollView
                }
            }
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
                  let index = mpd.queue.media.firstIndex(where: { $0.url == song.url })
            else {
                throw ViewError.missingData
            }

            #if os(macOS)
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
            #elseif os(iOS)
                let rowSpacing: CGFloat = 15
                let baseRowHeight: CGFloat = switch destination {
                case .albums, .artists: 50
                case .songs, .playlist, _: 31.5
                }
                let rowHeight = baseRowHeight + rowSpacing

                let rowMidY = (CGFloat(currentIndex) * rowHeight) + (rowHeight / 2)
                let visibleHeight = scrollView.frame.height
                let centeredOffset = rowMidY - (visibleHeight / 2)

                scrollView.setContentOffset(
                    CGPoint(x: 0, y: max(0, centeredOffset)),
                    animated: animate
                )
            #endif
        }
    }
}
