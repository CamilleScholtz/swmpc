//
//  View+Loading.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

extension View {
    func loadingOverlay(isLoading: Bool) -> some View {
        modifier(LoadingOverlayModifier(isLoading: isLoading))
    }
}

struct LoadingOverlayModifier: ViewModifier {
    let isLoading: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLoading {
                    ZStack {
                        Rectangle()
                            .fill(.background)
                            .ignoresSafeArea()

                        ProgressView()
                            .controlSize(.large)
                    }
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.animation(.easeOut(duration: 0.2).delay(0.2))
                    ))
                }
            }
    }
}
