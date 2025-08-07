//
//  PauseView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

import ButtonKit
import SwiftUI

struct PauseView: View {
    @Environment(MPD.self) private var mpd

    var size: CGFloat = 30
    var material: Material = .thinMaterial
    var animationDuration: Double = 0.4

    var body: some View {
        AsyncButton {
            try await ConnectionManager.command().pause(mpd.status.isPlaying)
        } label: {
            ZStack {
                Image(systemSymbol: .pauseFill)
                    .scaleEffect(mpd.status.isPlaying ? 1 : 0.1)
                    .opacity(mpd.status.isPlaying ? 1 : 0.1)

                Image(systemSymbol: .playFill)
                    .scaleEffect(mpd.status.isPlaying ? 0.1 : 1)
                    .opacity(mpd.status.isPlaying ? 0.1 : 1)
            }
            .font(.system(size: size))
            .foregroundStyle(.foreground)
            .animation(.interactiveSpring(duration: animationDuration, extraBounce: 0.3), value: mpd.status.isPlaying)
            .frame(width: size * 2.5, height: size * 2.5)
            .glassEffect(.regular)
            .contentShape(Circle())
        }
        .styledButton(hoverScale: 1.13)
    }
}
