//
//  LoadingView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct LoadingView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    @State private var isLoading = true

    var body: some View {
        ZStack {
            if isLoading {
                Rectangle()
                    .fill(.background)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ProgressView()
            }
        }
        .onChange(of: navigator.category) {
            isLoading = true
        }
        .task(id: mpd.queue.lastUpdated) {
            guard isLoading else {
                return
            }

            #if os(iOS)
                guard navigator.category != .playlists else {
                    withAnimation(.interactiveSpring) {
                        isLoading = false
                    }

                    return
                }

                guard mpd.queue.lastUpdated != nil, mpd.queue.lastUpdated! > Date.now.addingTimeInterval(-0.4) else {
                    return
                }
            #endif

            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else {
                return
            }

            withAnimation(.interactiveSpring) {
                isLoading = false
            }
        }
    }
}
