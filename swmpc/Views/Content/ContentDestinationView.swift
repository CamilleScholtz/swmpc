//
//  ContentDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/04/2025.
//

import SwiftUI

struct ContentDestinationView: View {
    @Environment(\.dismiss) private var dismiss

    let destination: ContentDestination

    var body: some View {
        List {
            switch destination {
            case let .album(album):
                AlbumSongsView(for: album)
            case let .artist(artist):
                ArtistAlbumsView(for: artist)
            }
        }
        .listRowSeparator(.hidden)
        #if os(iOS)
            .listRowInsets(.init(top: 7.5, leading: 15, bottom: 7.5, trailing: 15))
        #elseif os(macOS)
            .listRowInsets(.init(top: 7.5, leading: 7.5, bottom: 7.5, trailing: 7.5))
        #endif
            .listStyle(.plain)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .safeAreaPadding(.bottom, 7.5)
            .contentMargins(.bottom, -7.5, for: .scrollIndicators)
    }
}
