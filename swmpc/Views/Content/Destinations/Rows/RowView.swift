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
        .listRowSeparator(.hidden)
        #if os(iOS)
            .listRowInsets(.init(top: 7.5, leading: 15, bottom: 7.5, trailing: 15))
        #elseif os(macOS)
            .listRowInsets(.init(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5))
        #endif
    }
}
