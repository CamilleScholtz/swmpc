//
//  View+Swipe.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/04/2025.
//

import SwiftUI

extension View {
    /// Adds interactive swipe gestures (left/right) to the view, commonly used for next/previous actions.
    /// Includes visual feedback (offset, rotation) and haptic feedback on iOS.
    ///
    /// - Parameters:
    ///   - onSwipeLeft: An async closure executed when a left swipe is detected.
    ///   - onSwipeRight: An async closure executed when a right swipe is detected.
    /// - Returns: A view modified with the interactive swipe gesture.
    func swipeActions(
        onSwipeLeft: @escaping () -> Void,
        onSwipeRight: @escaping () -> Void
    ) -> some View {
        modifier(SwipeModifier(onSwipeLeft: onSwipeLeft, onSwipeRight: onSwipeRight))
    }
}

struct SwipeModifier: ViewModifier {
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    private let swipeThreshold: CGFloat = 100
    private let predictionFactor: CGFloat = 0.6

    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset.width)
            .rotationEffect(.degrees(dragOffset.width / 20 * ((dragOffset.height + 25) / 150)))
            .gesture(dragGesture)
            .animation(
                isDragging ? .interactiveSpring(response: 0.3, dampingFraction: 0.7) : .spring(response: 0.4, dampingFraction: 0.8),
                value: dragOffset
            )
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                isDragging = false

                let projectedEndWidth = value.translation.width + value.predictedEndTranslation.width * predictionFactor

                if projectedEndWidth < -swipeThreshold {
                    onSwipeLeft()
                } else if projectedEndWidth > swipeThreshold {
                    onSwipeRight()
                }

                resetOffset()
            }
    }

    private func resetOffset() {
        dragOffset = .zero
    }
}
