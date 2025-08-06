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
            case let artist as Artist:
                ArtistView(for: artist)
            case let song as Song:
                SongView(for: song)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 7.5)
    }
}
