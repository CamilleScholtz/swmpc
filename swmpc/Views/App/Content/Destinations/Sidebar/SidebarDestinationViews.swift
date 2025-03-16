//
//  SidebarDestinationViews.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import Navigator
import SwiftUI

extension SidebarDestination: NavigationDestination {
    var body: some View {
        SidebarDestinationView(destination: self)
    }
}

private struct SidebarDestinationView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator

    let destination: SidebarDestination
    
    var body: some View {
        ScrollViewReader { _ in
            ScrollView {
                HeaderView(selectedDestination: .constant(destination))
                    .id("top")
                
                LazyVStack(alignment: .leading, spacing: 15) {
                    switch destination {
                    case .albums:
                        AlbumsView()
                    case .artists:
                        ArtistsView()
                    case .songs, .playlist:
                        SongsView()
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
                .onChange(of: destination) { previous, value in
                    switch value {
                    case .albums, .artists, .songs:
                        guard mpd.status.playlist != nil else {
                            return
                        }
                    case let .playlist(playlist):
                        guard playlist != mpd.status.playlist else {
                            return
                        }
                    }
                    
                    navigator.perform(.playlistChangeRequired)
                }
            }
        }
    }
}
