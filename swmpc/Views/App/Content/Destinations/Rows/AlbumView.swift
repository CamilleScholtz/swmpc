//
//  AlbumView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct AlbumView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator

    private let album: Album

    init(for album: Album) {
        self.album = album
    }

    @State private var artwork: NSImage?
    @State private var isHovering = false
    @State private var isHoveringArtwork = false

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                ArtworkView(image: $artwork)
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                    .frame(width: 60)

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
            }
            .onHover(perform: { value in
                withAnimation(.interactiveSpring) {
                    isHoveringArtwork = value
                }
            })
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
        .id(album)
        .task(id: album, priority: .high) {
            try? await Task.sleep(nanoseconds: 48_000_000)
            guard !Task.isCancelled else {
                return
            }

            guard let data = try? await ArtworkManager.shared.get(for: album) else {
                return
            }

            artwork = NSImage(data: data)
        }
        .contentShape(Rectangle())
        .onHover(perform: { value in
            withAnimation(.interactiveSpring) {
                isHovering = value
            }
        })
        .onTapGesture {
            navigator.push(ContentDestination.album(album))
        }
        .contextMenu {
            Button("Add Album to Favorites") {
                Task {
                    try? await ConnectionManager.command().addToFavorites(songs: ConnectionManager.command().getSongs(for: album))
                }
            }

            if let playlists = (mpd.status.playlist != nil) ? mpd.queue.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.queue.playlists {
                Menu("Add Album to Playlist") {
                    ForEach(playlists) { playlist in
                        Button(playlist.name) {
                            Task {
                                try? await ConnectionManager.command().addToPlaylist(playlist, songs: ConnectionManager.command().getSongs(for: album))
                            }
                        }
                    }
                }
            }
        }
    }
}
