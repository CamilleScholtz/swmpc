//
//  RowView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct RowView: View {
    let media: any Mediable

    var body: some View {
        Group {
            switch media {
            case let album as Album:
                AlbumView(for: album)
                    .id(album)
            case let artist as Artist:
                ArtistView(for: artist)
                    .id(artist)
            case let song as Song:
                SongView(for: song)
                    .id(song)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, Layout.Padding.large)
        .padding(.vertical, Layout.Spacing.small)
    }
}
