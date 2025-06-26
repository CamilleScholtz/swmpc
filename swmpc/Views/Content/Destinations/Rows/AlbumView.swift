//
//  AlbumView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SwiftUI

struct AlbumView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    private let album: Album

    init(for album: Album) {
        self.album = album
    }

    @State private var artwork: PlatformImage?
    @State private var artworkTask: Task<Void, Never>?

    #if os(iOS)
        @State private var isShowingContextMenu = false
    #elseif os(macOS)
        @State private var isHovering = false
        @State private var isHoveringArtwork = false
        @State private var hoverHandler = HoverTaskHandler()
    #endif

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                ArtworkView(image: artwork)
                #if os(iOS)
                    .frame(width: 70)
                #elseif os(macOS)
                    .frame(width: 60)
                #endif
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.2), radius: 6)

                #if os(macOS)
                    if isHovering {
                        ZStack {
                            if isHoveringArtwork {
                                Circle()
                                    .fill(.accent)
                                    .frame(width: 40, height: 40)
                            }
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 40, height: 40)

                            Image(systemSymbol: .playFill)
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .transition(.opacity)
                    }
                #endif
            }
            #if os(macOS)
            .onHover { value in
                withAnimation(.interactiveSpring) {
                    isHoveringArtwork = value
                }
            }
            #endif
            .onTapGesture {
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().play(album)
                }
            }

            VStack(alignment: .leading) {
                Text(album.title)
                    .font(.headline)
                    .foregroundColor(mpd.status.media?.url == album.url ? .accentColor : .primary)
                    .lineLimit(2)

                Text(album.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        #if os(macOS)
            .onHoverWithDebounce(handler: hoverHandler) { hovering in
                withAnimation(.interactiveSpring) {
                    isHovering = hovering
                }
            }
        #endif
            .onTapGesture {
                navigator.navigate(to: ContentDestination.album(album))
            }
            .contextMenu {
                @AppStorage(Setting.simpleMode) var simpleMode = false
                if !simpleMode {
                    AlbumQueueToggleButton(album: album)
                    Divider()
                }

                Button("Copy Album Title") {
                    album.title.copyToClipboard()
                }

                Divider()

                AsyncButton("Add Album to Favorites") {
                    try await ConnectionManager.command().add(album: album, to: .favorites)
                }

                if let playlists = (mpd.status.playlist != nil) ? mpd.playlists.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.playlists.playlists {
                    Menu("Add Album to Playlist") {
                        ForEach(playlists) { playlist in
                            AsyncButton(playlist.name) {
                                try await ConnectionManager.command().add(album: album, to: .playlist(playlist))
                            }
                        }
                    }
                }
            }
            .task(id: album, priority: .high) {
                guard artwork == nil else {
                    return
                }

                artwork = try? await album.artwork()
            }
    }
}

struct AlbumQueueToggleButton: View {
    @Environment(MPD.self) private var mpd

    let album: Album

    @State private var songs: [Song]?

    private var actuallyInQueue: Bool {
        guard let songs else {
            return false
        }

        let urls = Set(mpd.queue.internalMedia.compactMap { ($0 as? Song)?.url })
        return songs.contains { urls.contains($0.url) }
    }

    var body: some View {
        AsyncButton(actuallyInQueue ? "Remove Album from Queue" : "Add Album to Queue") {
            if actuallyInQueue {
                try await ConnectionManager.command().remove(album: album, from: .queue)
            } else {
                try await ConnectionManager.command().add(album: album, to: .queue)
            }
        }
        .task(id: album) {
            songs = try? await ConnectionManager.command().getSongs(in: album, from: .database)
        }
    }
}
