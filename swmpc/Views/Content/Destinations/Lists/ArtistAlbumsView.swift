//
//  ArtistAlbumsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct ArtistAlbumsView: View {
    @Environment(MPD.self) private var mpd

    private var artist: Artist

    init(for artist: Artist) {
        self.artist = artist
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 15) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(artist.name)
                    #if os(iOS)
                        .font(.system(size: 24))
                    #elseif os(macOS)
                        .font(.system(size: 18))
                    #endif
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .lineLimit(3)
                        .contextMenu {
                            Button("Copy Artist Name") {
                                artist.name.copyToClipboard()
                            }
                        }

                    Text(artist.albums?.count ?? 0 > 1 ? "\(String(artist.albums!.count)) albums" : "1 album")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 5)
        .task(priority: .medium) {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: song, using: .album)
        }

        ForEach(artist.albums ?? []) { album in
            AlbumView(for: album)
        }
    }
}
