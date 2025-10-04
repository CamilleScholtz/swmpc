//
//  PreviousView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

import ButtonKit
import SwiftUI

// MARK: - Layout Constants

private extension Layout {
    enum Control {
        static let previousButtonMultiplier: CGFloat = 2.0
        static let previousSizeAdjustment: CGFloat = 5
    }
}

struct PreviousView: View {
    @Environment(MPD.self) private var mpd

    var size: CGFloat = 18

    @State private var animating = false

    private var value: CGFloat {
        animating ? 1 : 0
    }

    var body: some View {
        AsyncButton {
            withAnimation(.interactiveSpring(duration: 0.4, extraBounce: 0.3)) {
                if !animating {
                    animating = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    animating = false
                }
            }

            try await ConnectionManager.command {
                try await $0.previous()
            }
        } label: {
            VStack(alignment: .trailing) {
                HStack(spacing: -5) {
                    Image(systemSymbol: .arrowtriangleBackwardFill)
                        .opacity(1 - value)
                        .scaleEffect(1 - value)

                    Image(systemSymbol: .arrowtriangleBackwardFill)

                    Image(systemSymbol: .arrowtriangleBackwardFill)
                        .opacity(value)
                        .scaleEffect(value)
                }
                .font(.system(size: size))
                .offset(x: -value * (size - Layout.Control.previousSizeAdjustment))
                .offset(x: (size - Layout.Control.previousSizeAdjustment) / 3)
            }
            .frame(width: (size - Layout.Control.previousSizeAdjustment) * 2)
            .padding(Layout.Padding.large)
            .contentShape(Circle())
        }
        .styledButton()
        .disabled(mpd.status.song == nil)
        .help("Skip to previous track")
    }
}
