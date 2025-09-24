//
//  ContentDestinationView.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/04/2025.
//

import SwiftUI

struct ContentDestinationView: View {
    @Environment(NavigationManager.self) private var navigator

    let destination: ContentDestination

    var body: some View {
        switch destination {
        case let .album(album):
            List {
                AlbumSongsView(for: album)
            }
            .mediaListStyle()
        case let .artist(artist):
            List {
                ArtistAlbumsView(for: artist)
            }
            .mediaListStyle()
        #if os(iOS)
            case let .playlist(playlist):
                CategoryPlaylistView(playlist: playlist)
        #endif
        }
    }
}
