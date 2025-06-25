//
//  SongView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SwiftUI

struct SongView: View {
    @Environment(MPD.self) private var mpd

    private let song: Song
    private let isQueued: Bool
    private let isMoveable: Bool

    init(for song: Song, isQueued: Bool = false, isMoveable: Bool = false) {
        self.song = song
        self.isQueued = isQueued
        self.isMoveable = isMoveable
    }

    #if os(macOS)
        @State private var isHovering = false
        @State private var isHoveringHandle = false
        @State private var hoverHandler = HoverTaskHandler()
    #endif

    #if os(iOS)
        let trackSize: CGFloat = 30
    #elseif os(macOS)
        let trackSize: CGFloat = 20
    #endif

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 15) {
                ZStack {
                    Text(String(song.track))
                        .font(.headline)
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    #if os(macOS)
                        Image(systemSymbol: .playFill)
                            .font(.title3)
                            .foregroundColor(.accentColor)
                            .background(
                                Rectangle()
                                    .fill(.background)
                                    .frame(width: trackSize, height: trackSize)
                            )
                            .opacity(isHovering ? 1 : 0)
                    #endif

                    WaveView()
                        .background(
                            Rectangle()
                                .fill(.background)
                                .frame(width: trackSize, height: trackSize)
                        )
                        .opacity(mpd.status.song == song ? 1 : 0)
                }
                .frame(width: trackSize, height: trackSize)

                VStack(alignment: .leading) {
                    Text(song.title)
                        .font(.headline)
                        .foregroundColor(mpd.status.song == song ? .accentColor : .primary)
                        .lineLimit(2)

                    Text((song.artist) + " • " + song.duration.timeString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            #if os(iOS)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 10))
            #elseif os(macOS)
                .onHoverWithDebounce(handler: hoverHandler) { hovering in
                    withAnimation(.interactiveSpring) {
                        isHovering = hovering
                    }
                }
            #endif
                .onTapGesture {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().play(song)
                    }
                }
                .contextMenu {
                    @AppStorage(Setting.simpleMode) var simpleMode = false
                    if !simpleMode {
                        QueueToggleButton(song: song, isQueued: isQueued)
                        Divider()
                    }

                    Button("Copy Song Title") {
                        song.title.copyToClipboard()
                    }

                    Divider()

                    if mpd.status.playlist?.name != "Favorites" {
                        AsyncButton("Add Song to Favorites") {
                            try await ConnectionManager.command().addToFavorites(songs: [song])
                        }
                    }

                    if let playlists = (mpd.status.playlist != nil) ? mpd.playlists.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.playlists.playlists {
                        Menu("Add Song to Playlist") {
                            ForEach(playlists) { playlist in
                                AsyncButton(playlist.name) {
                                    try await ConnectionManager.command().addToPlaylist(playlist, songs: [song])
                                }
                            }
                        }

                        if let playlist = mpd.status.playlist {
                            Divider()

                            if mpd.status.playlist?.name == "Favorites" {
                                AsyncButton("Remove Song from Favorites") {
                                    try await ConnectionManager.command().removeFromFavorites(songs: [song])
                                }
                            } else {
                                AsyncButton("Remove Song from Playlist") {
                                    try await ConnectionManager.command().removeFromPlaylist(playlist, songs: [song])
                                }
                            }
                        }
                    }
                }

            if isMoveable {
                Image(systemSymbol: .line3HorizontalCircle)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .contentShape(.circle)
                    .padding(3)
                    .background(
                        Circle()
                            .fill(.background)
                    )
                    .opacity(isHoveringHandle ? 1 : 0)
                    .onHover { value in
                        isHoveringHandle = value
                    }
            }
        }
    }
}

struct WaveView: View {
    @Environment(MPD.self) private var mpd

    @State private var isAnimating = false

    var body: some View {
        let isPlaying = mpd.status.isPlaying

        HStack(spacing: 1.5) {
            bar(low: 0.4)
                .animation(isPlaying ? .linear(duration: 0.5).speed(1.5).repeatForever() : .linear(duration: 0.5), value: isAnimating)
            bar(low: 0.3)
                .animation(isPlaying ? .linear(duration: 0.5).speed(1.2).repeatForever() : .linear(duration: 0.5), value: isAnimating)
            bar(low: 0.5)
                .animation(isPlaying ? .linear(duration: 0.5).speed(1.0).repeatForever() : .linear(duration: 0.5), value: isAnimating)
            bar(low: 0.3)
                .animation(isPlaying ? .linear(duration: 0.5).speed(1.7).repeatForever() : .linear(duration: 0.5), value: isAnimating)
            bar(low: 0.5)
                .animation(isPlaying ? .linear(duration: 0.5).speed(1.0).repeatForever() : .linear(duration: 0.5), value: isAnimating)
        }
        .onAppear {
            isAnimating = isPlaying
        }
        .onDisappear {
            isAnimating = false
        }
        .onChange(of: isPlaying) { _, value in
            isAnimating = value
        }
    }

    private func bar(low: CGFloat = 0.0, high: CGFloat = 1.0) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.secondary)
            .frame(width: 2, height: (isAnimating ? high : low) * 12)
    }
}

struct QueueToggleButton: View {
    @Environment(MPD.self) private var mpd

    let song: Song
    let isQueued: Bool

    private var actuallyInQueue: Bool {
        isQueued || mpd.queue.internalMedia.contains {
            $0.url == song.url
        }
    }

    var body: some View {
        AsyncButton(actuallyInQueue ? "Remove Song from Queue" : "Add Song to Queue") {
            if actuallyInQueue {
                let queueSongs = mpd.queue.internalMedia as? [Song]
                if let queuedSong = queueSongs?.first(where: { $0.url == song.url }) {
                    try await ConnectionManager.command().removeFromQueue(songs: [queuedSong])
                }
            } else {
                try await ConnectionManager.command().addToQueue(songs: [song])
            }
        }
    }
}
