//
//  NextView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

import ButtonKit
import SwiftUI

struct NextView: View {
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

            try await ConnectionManager.command().next()
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
                .offset(x: value * (size - 5))
                .offset(x: -(size - 5) / 3)
            }
            .frame(width: (size - 5) * 2)
            .padding(12)
            .contentShape(Circle())
        }
        .styledButton()
    }
}
