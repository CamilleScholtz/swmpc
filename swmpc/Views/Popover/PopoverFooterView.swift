//
//  PopoverFooterView.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/03/2025.
//

import ButtonKit
import SwiftUI

struct PopoverFooterView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 15) {
            PlayerProgressView(showTimestamps: false)
                .frame(height: 9)
                .padding(.horizontal, 15)

            HStack(alignment: .center, spacing: 0) {
                RepeatView()
                    .offset(x: 10)

                Spacer()

                HStack(spacing: 2) {
                    PreviousView(size: 14)
                    PopoverPauseView()
                    NextView(size: 14)
                }

                Spacer()

                RandomView()
                    .offset(x: -10)
            }
            .asyncButtonStyle(.pulse)
            .frame(width: 250 - 30)
            .offset(y: -4)
        }
        .frame(height: 80)
        .blendMode(.softLight)
        .background(.regularMaterial)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5),
        )
        .padding(1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.black.opacity(0.2), lineWidth: 1),
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.15 : 0.05), radius: 3, x: 0, y: 2)
        .shadow(radius: 20)
    }

    struct PopoverPauseView: View {
        @Environment(MPD.self) private var mpd

        var body: some View {
            AsyncButton {
                try await ConnectionManager.command().pause(mpd.status.isPlaying)
            } label: {
                ZStack {
                    Circle()
                        .fill(.primary)
                        .frame(width: 36, height: 36)

                    ZStack {
                        Image(systemSymbol: .pauseFill)
                            .font(.system(size: 18))
                            .scaleEffect(mpd.status.isPlaying ? 1 : 0.1)
                            .opacity(mpd.status.isPlaying ? 1 : 0.1)

                        Image(systemSymbol: .playFill)
                            .font(.system(size: 18))
                            .scaleEffect(mpd.status.isPlaying ? 0.1 : 1)
                            .opacity(mpd.status.isPlaying ? 0.1 : 1)
                    }
                    .animation(.interactiveSpring(duration: 0.25), value: mpd.status.isPlaying)
                    .blendMode(.destinationOut)
                }
            }
            .styledButton(hoverScale: 1.1)
        }
    }
}
