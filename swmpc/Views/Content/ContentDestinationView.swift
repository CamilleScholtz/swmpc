//
//  ContentDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/04/2025.
//

import SwiftUI

struct ContentDestinationView: View {
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
        .mediaListStyle()
    }
}
