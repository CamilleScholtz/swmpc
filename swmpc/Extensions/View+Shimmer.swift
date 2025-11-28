//
//  View+Shimmer.swift
//  swmpc
//
//  Created by Camille Scholtz on 28/11/2025.
//

import SwiftUI

struct Shimmer: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.1),
                                .white.opacity(0.1),
                                .white.opacity(0.4),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    )
                    .blendMode(.plusLighter)
                    .opacity(opacity)
            }
    }
}

extension View {
    func shimmer(cornerRadius: CGFloat, opacity: Double = 1.0) -> some View {
        modifier(Shimmer(cornerRadius: cornerRadius, opacity: opacity))
    }
}
