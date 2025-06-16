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
                    .frame(width: 65)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 1)

                #if os(macOS)
                    Image(systemSymbol: .playFill)
                        .font(.title2)
                        .padding(10)
                        .glassEffect(.regular.tint(isHoveringArtwork ? .accent.opacity(0.5) : .clear))
                        .opacity(isHovering ? 1 : 0)
                        .animation(.interactiveSpring, value: isHovering)
                        .animation(.interactiveSpring, value: isHoveringArtwork)
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
                    AsyncButton("Add to Queue") {
                        try await mpd.queue.add(album: album)
                    }

                    Divider()
                }

                Button("Copy Album Title") {
                    album.title.copyToClipboard()
                }

                Divider()

                AsyncButton("Add Album to Favorites") {
                    try await ConnectionManager.command().addToFavorites(songs: ConnectionManager.command().getSongs(using: .queue, for: album))
                }

                if let playlists = (mpd.status.playlist != nil) ? mpd.database.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.database.playlists {
                    Menu("Add Album to Playlist") {
                        ForEach(playlists) { playlist in
                            AsyncButton(playlist.name) {
                                try await ConnectionManager.command().addToPlaylist(playlist, songs: ConnectionManager.command().getSongs(using: .queue, for: album))
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
