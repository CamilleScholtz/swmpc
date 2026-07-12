//
//  ArtistView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import MPDKit
import SwiftUI

struct ArtistView: View, Equatable {
    @Environment(NavigationManager.self) private var navigator

    private let artist: Artist

    init(for artist: Artist) {
        self.artist = artist
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.artist == rhs.artist
    }

    @State private var albumCount: Int = 0

    var body: some View {
        Button {
            navigator.navigate(to: ContentDestination.artist(artist))
        } label: {
            HStack(spacing: Layout.Spacing.large) {
                ArtistImageView(for: artist, size: Layout.RowHeight.artist, initialsFontSize: 18)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 1)

                VStack(alignment: .leading) {
                    ArtistNameText(artist: artist)

                    Text(albumCount == 1 ? "1 album" : "\(albumCount) albums")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            ContextMenuView(for: artist)
        }
        .task(id: artist, priority: .medium) {
            guard !Task.isCancelled else {
                return
            }

            albumCount = await (try? artist.getAlbums().count) ?? 0
        }
    }
}

private struct ArtistNameText: View {
    @Environment(MPD.self) private var mpd
    let artist: Artist

    var body: some View {
        Text(artist.name)
            .font(.headline)
            .foregroundStyle(mpd.status.song?.isBy(artist) ?? false ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            .lineLimit(2)
    }
}
