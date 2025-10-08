//
//  PopoverFooterView.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/03/2025.
//

import ButtonKit
import SwiftUI

struct PopoverFooterView: View {
    var body: some View {
        VStack(alignment: .center, spacing: Layout.Spacing.small) {
            PlayerProgressView(showTimestamps: false)
                .padding(.horizontal, Layout.Padding.large)
                .padding(.top, Layout.Padding.small)

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
            .frame(width: Layout.Size.popoverContentWidth)
            .offset(y: -4)
        }
        .frame(height: Layout.Size.popoverFooterHeight)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Layout.CornerRadius.medium))
    }

    struct PopoverPauseView: View {
        @Environment(MPD.self) private var mpd

        var body: some View {
            AsyncButton {
                try await ConnectionManager.command {
                    try await $0.pause(mpd.status.isPlaying)
                }
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
