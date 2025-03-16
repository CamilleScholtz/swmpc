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
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 15) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(artist.name)
                            .font(.system(size: 18))
                            .fontWeight(.semibold)
                            .fontDesign(.rounded)
                            .lineLimit(3)

                        Text(artist.albums?.count ?? 0 > 1 ? "\(String(artist.albums!.count)) albums" : "1 album")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 15)

                ForEach(artist.albums ?? []) { album in
                    AlbumView(for: album)
                }
            }
            .padding(.leading, 15)
            .padding(.trailing, 15)
        }
        .task {
            guard let song = mpd.status.song else {
                return
            }

            mpd.status.media = try? await mpd.queue.get(for: song, using: .album)
        }
    }
}
