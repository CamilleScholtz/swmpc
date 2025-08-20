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

    @State private var albums: [Album] = []

    var body: some View {
        Section {
            HStack(spacing: Layout.Spacing.large) {
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
                            ContextMenuView(for: artist)
                        }

                    Text(albums.count == 1 ? "1 album" : "\(albums.count) albums")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(Layout.Padding.large)
        }
        .task {
            albums = await (try? artist.getAlbums()) ?? []
        }

        Section {
            ForEach(albums) { album in
                RowView(media: album)
            }
        }
    }
}
