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
            guard navigator.category.type != .playlist else {
                return
            }

            isLoading = true
        }
        .task(id: navigator.category) {
            await checkAndHideLoading()
        }
        .task(id: mpd.database.lastUpdated) {
            await checkAndHideLoading()
        }
    }

    private func checkAndHideLoading() async {
        guard isLoading else {
            return
        }

        #if os(iOS)
            if navigator.category == .playlists {
                if mpd.database.playlists != nil {
                    try? await Task.sleep(for: .milliseconds(200))
                    guard !Task.isCancelled else {
                        return
                    }

                    isLoading = false
                }

                return
            }
        #endif

        if navigator.category.type == mpd.database.type, !mpd.database.internalMedia.isEmpty {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else {
                return
            }

            isLoading = false
        }
    }
}
