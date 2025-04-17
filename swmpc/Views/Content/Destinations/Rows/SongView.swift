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

    init(for song: Song) {
        self.song = song
    }

    @State private var duration: String?
    #if os(macOS)
        @State private var isHovering = false
    #endif

    var body: some View {
        HStack(spacing: 15) {
            Group {
                if mpd.status.song != song {
                    #if os(iOS)
                        Text(String(song.track))
                            .font(.title3)
                            .fontWeight(.regular)
                            .foregroundStyle(.secondary)
                            .frame(width: 60)
                    #elseif os(macOS)
                        if isHovering {
                            Image(systemSymbol: .playFill)
                                .font(.title3)
                                .foregroundColor(.accentColor)
                                .transition(.opacity)
                        } else {
                            Text(String(song.track))
                                .font(.title3)
                                .fontWeight(.regular)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                        }
                    #endif
                } else {
                    WaveView()
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                    .foregroundColor(mpd.status.song == song ? .accentColor : .primary)
                    .lineLimit(2)

                Text((song.artist) + " • " + (duration ?? "0:00"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .onAppear {
                        duration = song.duration.timeString
                    }
            }

            Spacer()
        }
        .id(song.id)
        .contentShape(Rectangle())
        #if os(macOS)
            .onHover(perform: { value in
                isHovering = value
            })
        #endif
            .onTapGesture(perform: {
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().play(song)
                }
            })
            .contextMenu {
                if mpd.status.playlist?.name != "Favorites" {
                    AsyncButton("Add Song to Favorites") {
                        try await ConnectionManager.command().addToFavorites(songs: [song])
                    }
                }

                if let playlists = (mpd.status.playlist != nil) ? mpd.queue.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.queue.playlists {
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
