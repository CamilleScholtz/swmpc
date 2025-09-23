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
        case .albums, .artists, .songs, .playlist:
            return mpd.state.isLoading
        #if os(iOS)
            case .playlists:
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
                #if os(macOS)
                    .controlSize(.large)
                #endif
            }
            .transition(.asymmetric(
                insertion: .opacity,
                removal: .opacity.animation(.easeOut(duration: 0.2).delay(0.2)),
            ))
        }
    }
}
