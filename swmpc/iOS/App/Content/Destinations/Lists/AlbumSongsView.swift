//
//  AlbumSongsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct AlbumSongsView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator
    @Environment(\.colorScheme) private var colorScheme

    init(for album: Album) {
        _album = State(initialValue: album)
    }

    @State private var album: Album
    @State private var artwork: UIImage?
    @State private var songs: [Int: [Song]]?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 15) {
                if artwork != nil {
                    Button(action: {
                        Task(priority: .userInitiated) {
                            if mpd.status.media?.id != album.id {
                                try? await ConnectionManager.command().play(album)
                            }
                        }
                    }) {
                        ArtworkView(image: $artwork)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Group {
                                    if mpd.status.media?.id == album.id {
                                        VStack {
                                            Spacer()
                                            HStack(spacing: 5) {
                                                Image(systemSymbol: .playFill)
                                                Text("Playing")
                                            }
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(.regularMaterial)
                                            .cornerRadius(100)
                                            .padding(10)
                                        }
                                    }
                                }
                            )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Add Album to Favorites") {
                            Task {
                                try? await ConnectionManager.command().addToFavorites(songs: songs?.values.flatMap(\.self) ?? [])
                            }
                        }

                        if let playlists = (mpd.status.playlist != nil) ? mpd.queue.playlists?.filter({ $0 != mpd.status.playlist }) : mpd.queue.playlists {
                            Menu("Add Album to Playlist") {
                                ForEach(playlists) { playlist in
                                    Button(playlist.name) {
                                        Task {
                                            try? await ConnectionManager.command().addToPlaylist(playlist, songs: songs?.values.flatMap(\.self) ?? [])
                                        }
                                    }
                                }
                            }

                            if let playlist = mpd.status.playlist {
                                Button("Remove Album from Playlist") {
                                    Task {
                                        try? await ConnectionManager.command().removeFromPlaylist(playlist, songs: songs?.values.flatMap(\.self) ?? [])
                                    }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(album.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(3)

                    Button(action: {
                        Task(priority: .userInitiated) {
                            guard let artist = try? await mpd.queue.get(for: album, using: .artist) as? Artist else {
                                return
                            }
                            navigator.push(ContentDestination.artist(artist))
                        }
                    }) {
                        Text(album.artist)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if let songs {
                        let flat = songs.values.flatMap(\.self)
                        Text((flat.count > 1 ? "\(String(flat.count)) songs" : "1 song")
                            + " • "
                            + (flat.reduce(0) { $0 + $1.duration }.humanTimeString))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 5)
            .task {
                async let artworkDataTask = ArtworkManager.shared.get(for: album, shouldCache: true)
                async let songsTask = ConnectionManager.command().getSongs(for: album)

                artwork = await UIImage(data: (try? artworkDataTask) ?? Data())
                songs = await Dictionary(grouping: (try? songsTask) ?? [], by: { $0.disc })
            }
        }
        .padding(.bottom, 15)

        if let songs {
            ForEach(songs.keys.sorted(), id: \.self) { disc in
                VStack(alignment: .leading, spacing: 15) {
                    if songs.keys.count > 1 {
                        Text("Disc \(String(disc))")
                            .font(.headline)
                            .padding(.top, disc == songs.keys.sorted().first ? 0 : 10)
                    }

                    ForEach(songs[disc] ?? []) { song in
                        SongView(for: song)
                    }
                }
            }
        }
    }
}
