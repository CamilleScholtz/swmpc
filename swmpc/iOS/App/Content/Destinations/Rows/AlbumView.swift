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

    @State private var artwork: UIImage?
    @State private var isShowingContextMenu = false

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                ArtworkView(image: $artwork)
                    .cornerRadius(5)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemSymbol: .playFill)
                            .font(.title3)
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 40, height: 40)
                            )
                            .opacity(0)
                    )
                    .onTapGesture {
                        Task(priority: .userInitiated) {
                            try? await ConnectionManager.command().play(album)
                        }
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
            guard !Task.isCancelled else {
                return
            }

            guard let data = try? await ArtworkManager.shared.get(for: album), !Task.isCancelled else {
                return
            }

            artwork = UIImage(data: data)
        }
        .contentShape(Rectangle())
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
        .padding(.vertical, 4)
    }
}
