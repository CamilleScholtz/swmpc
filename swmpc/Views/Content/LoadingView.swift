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

            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.interactiveSpring) {
                isLoading = false
            }
        }
    }
}
