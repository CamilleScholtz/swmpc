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
    @State private var artwork: NSImage?
    @State private var songs: [Int: [Song]]?

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 15) {
                if artwork != nil {
                    ZStack {
                        ZStack(alignment: .bottom) {
                            ArtworkView(image: $artwork)
                                .frame(width: 80)
                                .blur(radius: 17)
                                .offset(y: 7)
                                .saturation(1.5)
                                .blendMode(colorScheme == .dark ? .softLight : .normal)
                                .opacity(0.5)

                            ArtworkView(image: $artwork)
                                .cornerRadius(10)
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                                .frame(width: 100)
                                .overlay(
                                    ZStack(alignment: .bottomLeading) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 100)
                                            .mask(
                                                LinearGradient(
                                                    gradient: Gradient(stops: [
                                                        .init(color: .black, location: 0.3),
                                                        .init(color: .black.opacity(0), location: 1.0),
                                                    ]),
                                                    startPoint: .bottom,
                                                    endPoint: .top
                                                )
                                            )

                                        HStack(spacing: 5) {
                                            Image(systemSymbol: .playFill)
                                            Text("Playing")
                                        }
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(.white)
                                        .cornerRadius(100)
                                        .padding(10)
                                    }
                                    .opacity(mpd.status.media?.id == album.id ? 1 : 0)
                                    .animation(.interactiveSpring, value: mpd.status.media?.id == album.id)
                                )
                        }

                        if isHovering, mpd.status.media?.id != album.id {
                            ZStack {
                                Circle()
                                    .fill(.accent)
                                    .frame(width: 60, height: 60)
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 60, height: 60)

                                Image(systemSymbol: .playFill)
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            .transition(.opacity)
                        }
                    }
                    .onHover(perform: { value in
                        withAnimation(.interactiveSpring) {
                            isHovering = value
                        }
                    })
                    .onTapGesture(perform: {
                        Task(priority: .userInitiated) {
                            if mpd.status.media?.id != album.id {
                                try? await ConnectionManager.command().play(album)
                            }
                        }
                    })
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
                        .font(.system(size: 18))
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .lineLimit(3)

                    Text(album.artist)
                        .font(.system(size: 12))
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .onTapGesture(perform: {
                            Task(priority: .userInitiated) {
                                guard let artist = try? await mpd.queue.get(for: album, using: .artist) as? Artist else {
                                    return
                                }
                                navigator.push(ContentDestination.artist(artist))
                            }
                        })

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
            .task {
                async let artworkDataTask = ArtworkManager.shared.get(for: album, shouldCache: true)
                async let songsTask = ConnectionManager.command().getSongs(for: album)

                artwork = await NSImage(data: (try? artworkDataTask) ?? Data())
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
