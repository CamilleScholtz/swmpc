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
            Group {
                #if os(iOS)
                    VStack(spacing: Layout.Spacing.large) {
                        Circle()
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 90, height: 90)
                            .overlay(
                                ZStack {
                                    Text(artist.name.initials)
                                        .font(.system(size: 40))
                                        .fontDesign(.rounded)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)

                                    Color.clear
                                        .glassEffect(.clear, in: Circle())
                                        .mask(
                                            RadialGradient(
                                                stops: [
                                                    .init(color: .clear, location: 0.0),
                                                    .init(color: .black, location: 1.0),
                                                ],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 90,
                                            ),
                                        )
                                },
                            )
                            .shadow(color: .black.opacity(0.2), radius: Layout.Padding.medium, y: 6)

                        VStack(alignment: .center) {
                            Text(artist.name)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .fontDesign(.rounded)
                                .lineLimit(3)
                                .multilineTextAlignment(.center)

                            Text(albums.count == 1 ? "1 album" : "\(albums.count) albums")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Layout.Spacing.medium)
                    .contextMenu {
                        ContextMenuView(for: artist)
                    }
                #else
                    HStack(spacing: Layout.Spacing.large) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(artist.name)
                                .font(.system(size: 18))
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
                    .padding(.bottom, Layout.Spacing.medium)
                #endif
            }
        }
        .mediaRowStyle()
        .task {
            albums = await (try? artist.getAlbums()) ?? []
        }

        Section {
            ForEach(albums) { album in
                AlbumView(for: album)
                    .equatable()
                    .mediaRowStyle()
            }
        }
    }
}
