//
//  LoadingView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import NavigatorUI
import SwiftUI

struct LoadingView: View {
    @Environment(MPD.self) private var mpd

    let destination: SidebarDestination

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
        .onChange(of: destination) {
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
