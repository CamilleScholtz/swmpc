//
//  ArtistAlbumsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import MPDKit
import SwiftUI

struct ArtistAlbumsView: View {
    @Environment(MPD.self) private var mpd

    private var artist: Artist

    init(for artist: Artist) {
        self.artist = artist
    }

    @State private var albums: [Album] = []
    @State private var info: ArtistInfo?

    var body: some View {
        Section {
            ArtistHeaderView(artist: artist, albumCount: albums.count, info: info)
        }
        .mediaRowStyle()
        .task {
            albums = await (try? artist.getAlbums()) ?? []
            info = await ArtistArtworkManager.shared.info(for: artist)
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

private struct ArtistHeaderView: View {
    let artist: Artist
    let albumCount: Int
    let info: ArtistInfo?

    var body: some View {
        #if os(iOS)
            VStack(spacing: Layout.Spacing.large) {
                ArtistImageView(for: artist, size: 180, initialsFontSize: 80)
                    .shadow(color: .black.opacity(0.2), radius: Layout.Padding.medium, y: 6)
                    .contextMenu {
                        ContextMenuView(for: artist)
                    }

                VStack(alignment: .center) {
                    Text(artist.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)

                    ArtistSummaryView(albumCount: albumCount, genres: info?.genres ?? [])
                }

                if let bio = info?.bio {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, Layout.Spacing.medium)
        #elseif os(macOS)
            HStack(spacing: Layout.Spacing.large) {
                ArtistImageView(for: artist, size: 100, initialsFontSize: 44)
                    .shadow(color: .black.opacity(0.2), radius: Layout.Padding.small, y: 4)
                    .contextMenu {
                        ContextMenuView(for: artist)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(artist.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .lineLimit(3)

                    ArtistSummaryView(albumCount: albumCount, genres: info?.genres ?? [])

                    if let bio = info?.bio {
                        Text(bio)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .padding(.top, 3)
                    }
                }

                Spacer()
            }
            .padding(.bottom, Layout.Spacing.medium)
        #endif
    }
}

private struct ArtistSummaryView: View {
    let albumCount: Int
    let genres: [String]

    var body: some View {
        let count = albumCount == 1
            ? String(localized: "1 album")
            : String(localized: "\(albumCount) albums")
        let details = genres.isEmpty
            ? count
            : count + " • " + genres.prefix(2).joined(separator: " • ")

        Text(details)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}
