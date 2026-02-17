//
//  NextView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

import ButtonKit
import MPDKit
import SwiftUI

private extension Layout {
    enum Control {
        static let nextSizeAdjustment: CGFloat = 5
    }
}

struct NextView: View {
    @Environment(MPD.self) private var mpd

    let size: CGFloat

    @State private var animating = false

    private var value: CGFloat {
        animating ? 1 : 0
    }

    var body: some View {
        AsyncButton {
            withAnimation(.interactiveSpring(duration: 0.4, extraBounce: 0.3)) {
                animating = true
            }

            Task {
                try? await Task.sleep(for: .milliseconds(400))
                animating = false
            }

            try await ConnectionManager.command {
                try await $0.next()
            }
        } label: {
            VStack(alignment: .leading) {
                HStack(spacing: -5) {
                    Image(systemSymbol: .arrowtriangleForwardFill)
                        .opacity(value)
                        .scaleEffect(value)

                    Image(systemSymbol: .arrowtriangleForwardFill)

                    Image(systemSymbol: .arrowtriangleForwardFill)
                        .opacity(1 - value)
                        .scaleEffect(1 - value)
                }
                .font(.system(size: size))
                .offset(x: value * (size - Layout.Control.nextSizeAdjustment))
                .offset(x: -(size - Layout.Control.nextSizeAdjustment) / 3)
            }
            .frame(width: (size - Layout.Control.nextSizeAdjustment) * 2)
            .padding(Layout.Padding.large)
            .contentShape(Circle())
        }
        .styledButton()
        .disabled(mpd.status.song == nil)
        .help("Skip to next track")
    }
}
