//
//  PopoverFooterView.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/03/2025.
//

import ButtonKit
import SwiftUI

private extension Layout.Size {
    static let progressSeparatorHeight: CGFloat = 9
    static let popoverPauseIcon: CGFloat = 36
}

struct PopoverFooterView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Layout.Spacing.large) {
            PlayerProgressView(showTimestamps: false)
                .frame(height: Layout.Size.progressSeparatorHeight)
                .padding(.horizontal, Layout.Padding.large)

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
                        .frame(width: Layout.Size.popoverPauseIcon, height: Layout.Size.popoverPauseIcon)

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
