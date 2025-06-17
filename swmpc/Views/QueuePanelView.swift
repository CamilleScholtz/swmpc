//
//  QueuePanelView.swift
//  swmpc
//
//  Created by Camille Scholtz on 06/02/2025.
//

import ButtonKit
import SwiftUI

struct QueuePanelView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    @Binding var showQueuePanel: Bool

    @State private var showClearQueueAlert = false
    @State private var songs: [Song]?

    private let queueChangedNotification = NotificationCenter.default
        .publisher(for: .queueChangedNotification)

    var body: some View {
        VStack(spacing: 0) {
            if songs == nil || songs!.isEmpty {
                EmptyQueueView()
            } else {
                QueueView(songs: songs!)
            }
        }
        .safeAreaInset(edge: .top, spacing: 7.5) {
            HStack {
                Text("Queue")
                    .font(.headline)

                Spacer()

                HStack(spacing: 4) {
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
                    .opacity(songs == nil || songs!.isEmpty ? 0 : 1)

                    Button(action: {
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
        .task {
            songs = try? await ConnectionManager.command().getSongs(using: .queue)
        }
        .onReceive(queueChangedNotification) { _ in
            Task {
                songs = try? await ConnectionManager.command().getSongs(using: .queue)
            }
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

        let songs: [Song]

        var body: some View {
            ScrollViewReader { _ in
                List(songs) { song in
                    SongView(for: song, isQueued: true)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5))
                }
                .listStyle(.plain)
                .safeAreaPadding(.bottom, 7.5)
                .contentMargins(.vertical, -7.5, for: .scrollIndicators)
                .environment(\.defaultMinListRowHeight, min(31.5 + 15, 50))
                .onAppear {
                    //                if let currentSong = mpd.status.media as? Song,
                    //                   let songId = currentSong.id {
                    //                    proxy.scrollTo(songId, anchor: .center)
                    //                }
                }
            }
        }
    }
}
