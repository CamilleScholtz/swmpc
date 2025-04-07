//
//  AlbumView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI
#if os(iOS)
    import SFSafeSymbols
#endif

struct AlbumView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    private let album: Album

    init(for album: Album) {
        self.album = album
    }

    @State private var artwork: PlatformImage?

    #if os(iOS)
        @State private var isShowingContextMenu = false
    #elseif os(macOS)
        @State private var isHovering = false
        @State private var isHoveringArtwork = false
    #endif

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                ArtworkView(image: artwork)
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                    .frame(width: 60)

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
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .transition(.opacity)
                    }
                #endif
            }
            #if os(macOS)
            .onHover(perform: { value in
                withAnimation(.interactiveSpring) {
                    isHoveringArtwork = value
                }
            })
            #endif
            .onTapGesture {
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().play(album)
                }
            }

            VStack(alignment: .leading) {
                Text(album.title)
                    .font(.headline)
                    .foregroundColor(mpd.status.media?.id == album.id ? .accentColor : .primary)
                    .lineLimit(2)
                Text(album.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .id(album.id)
        .contentShape(Rectangle())
        .task(id: album, priority: .medium) {
            guard !Task.isCancelled else {
                return
            }

            guard let data = try? await ArtworkManager.shared.get(for: album), !Task.isCancelled else {
                return
            }

            artwork = PlatformImage(data: data)
        }
        #if os(macOS)
        .onHover(perform: { value in
            withAnimation(.interactiveSpring) {
                isHovering = value
            }
        })
        #endif
        .onTapGesture {
            navigator.navigate(to: ContentDestination.album(album))
        }
        .contextMenu {
            Button("Add Album to Favorites") {
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().addToFavorites(songs: ConnectionManager.command().getSongs(for: album))
                }
            }

            if let playlists = (mpd.status.playlist != nil) ? mpd.queue.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.queue.playlists {
                Menu("Add Album to Playlist") {
                    ForEach(playlists) { playlist in
                        Button(playlist.name) {
                            Task(priority: .userInitiated) {
                                try? await ConnectionManager.command().addToPlaylist(playlist, songs: ConnectionManager.command().getSongs(for: album))
                            }
                        }
                    }
                }
            }
        }
    }
}
