//
//  LoadingView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/06/2025.
//

import SwiftUI

struct LoadingView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    private var shouldShowLoading: Bool {
        switch navigator.category {
        case .albums, .artists, .songs:
            return mpd.state.isLoading([.database])
        case let .playlist(playlist):
            return mpd.state.isLoading([.playlist(playlist)])
        #if os(iOS)
            case .playlists, .settings:
                return false
        #endif
        }
    }

    var body: some View {
        if shouldShowLoading {
            ZStack {
                Rectangle()
                    .fill(.background)
                    .ignoresSafeArea()

                ProgressView()
                    .controlSize(.large)
            }
            .transition(.asymmetric(
                insertion: .opacity,
                removal: .opacity.animation(.easeOut(duration: 0.2).delay(0.2))
            ))
        }
    }
}
