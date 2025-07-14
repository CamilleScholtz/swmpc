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
                Circle()
                    .fill(material)
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)

                ZStack {
                    Image(systemSymbol: .pauseFill)
                        .font(.system(size: size))
                        .scaleEffect(mpd.status.isPlaying ? 1 : 0.1)
                        .opacity(mpd.status.isPlaying ? 1 : 0.1)

                    Image(systemSymbol: .playFill)
                        .font(.system(size: size))
                        .scaleEffect(mpd.status.isPlaying ? 0.1 : 1)
                        .opacity(mpd.status.isPlaying ? 0.1 : 1)
                }
                .animation(.interactiveSpring(duration: animationDuration, extraBounce: 0.3), value: mpd.status.isPlaying)
            }
        }
        .styledButton(hoverScale: 1.13)
    }
}
