//
//  ArtistAlbumsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct ArtistAlbumsView: View {
    @Environment(MPD.self) private var mpd
    #if os(macOS)
        @Environment(\.colorScheme) private var colorScheme
    #endif

    private var artist: Artist

    init(for artist: Artist) {
        self.artist = artist
    }

    @State private var albums: [Album] = []

    var body: some View {
        Section {
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
                            ContextMenuView(for: artist)
                        }

                    Text(albums.count == 1 ? "1 album" : "\(albums.count) albums")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.bottom, 15)
            #if os(iOS)
                .listRowInsets(.init(top: 7.5, leading: 15, bottom: 15 + 7.5, trailing: 15))
            #elseif os(macOS)
                .listRowInsets(.init(top: 15, leading: 7.5, bottom: 7.5, trailing: 7.5))
            #endif
        }
        #if os(macOS)
        .frame(width: 310)
        #endif
        .overlay(
            Rectangle()
            #if os(iOS)
                .foregroundColor(Color(.secondarySystemFill))
            #elseif os(macOS)
                .foregroundColor(colorScheme == .dark ? .black : Color(.secondarySystemFill))
                .offset(x: -15)
            #endif
                .frame(height: 1),
            alignment: .bottom
        )
        .task {
            albums = await (try? artist.getAlbums()) ?? []
        }

        Section {
            ForEach(albums) { album in
                AlbumView(for: album)
            }
        }
    }
}
