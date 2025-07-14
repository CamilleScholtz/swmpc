//
//  LoadingView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/06/2025.
//

import SwiftUI

struct LoadingView: View {
    @Environment(MPD.self) private var mpd

    var body: some View {
        if mpd.state.isLoading {
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
