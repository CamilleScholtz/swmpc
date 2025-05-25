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
        .task(id: navigator.category) {
            await checkAndHideLoading()
        }
        .task(id: mpd.queue.lastUpdated) {
            await checkAndHideLoading()
        }
    }

    private func checkAndHideLoading() async {
        guard isLoading else {
            return
        }

        #if os(iOS)
            if navigator.category == .playlists {
                if mpd.queue.playlists != nil {
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation(.interactiveSpring) {
                        isLoading = false
                    }
                }
                return
            }
        #endif

        if mpd.queue.type == navigator.category.type, !mpd.queue.media.isEmpty {
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
