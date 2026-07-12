//
//  LoadingView.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/06/2025.
//

import Observation
import SwiftUI

struct LoadingView: View {
    @Environment(MPD.self) private var mpd

    /// Mirror of `mpd.state.isLoading`, fed asynchronously by the
    /// `Observations` sequence below.
    @State private var isLoading = true

    var body: some View {
        // Showing tracks the live value so the overlay appears in the same
        // transaction as the content change it is meant to cover; the mirror
        // only gates hiding. That keeps hiding robust: the startup
        // `true -> false` flip races the scene's first commit, and SwiftUI's
        // one-shot body observation can consume it without ever scheduling a
        // re-render — the mirror's `@State` update forces one regardless.
        // Both properties must be read unconditionally: `live || isLoading`
        // would short-circuit past the mirror, SwiftUI would record no
        // dependency on it, and its updates would no longer re-render this
        // view.
        let live = mpd.state.isLoading
        let mirrored = isLoading
        let visible = live || mirrored

        ZStack {
            Rectangle()
                .fill(.background)
                .ignoresSafeArea()

            ProgressView()
            #if os(macOS)
                .controlSize(.large)
            #endif
        }
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .animation(visible ? nil : .easeOut(duration: 0.2).delay(0.3), value: visible)
        .task {
            isLoading = mpd.state.isLoading

            for await value in Observations({ mpd.state.isLoading }) {
                isLoading = value
            }
        }
    }
}
