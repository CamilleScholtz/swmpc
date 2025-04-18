//
//  View+Swipe.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/04/2025.
//

import SwiftUI

extension View {
    /// Adds interactive swipe gestures (left/right) to the view, commonly used
    /// for next/previous actions. Includes visual feedback (offset, rotation)
    /// and sensory feedback on threshold crossing.
    ///
    /// - Parameters:
    ///   - onSwipeLeft: An closure executed when a left swipe gesture ends
    ///                  beyond the threshold.
    ///   - onSwipeRight: An closure executed when a right swipe gesture ends
    ///                   beyond the threshold.
    /// - Returns: A view modified with the interactive swipe gesture.
    func swipeActions(
        onSwipeLeft: @escaping () -> Void,
        onSwipeRight: @escaping () -> Void
    ) -> some View {
        modifier(SwipeModifier(onSwipeLeft: onSwipeLeft,
                               onSwipeRight: onSwipeRight))
    }
}

struct SwipeModifier: ViewModifier {
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    private enum ThresholdSide { case left, right }
    @State private var lastTriggeredThreshold: ThresholdSide? = nil

    private let swipeThreshold: CGFloat = 100
    private let predictionFactor: CGFloat = 0.6
    private let rotationAngleMultiplier: CGFloat = 1 / 40

    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset.width)
            .rotationEffect(.degrees(dragOffset.width * rotationAngleMultiplier))
            .gesture(dragGesture)
            .animation(
                isDragging
                    ? .interactiveSpring(response: 0.2, dampingFraction: 0.8)
                    : .spring(response: 0.4, dampingFraction: 0.7),
                value: dragOffset
            )
            .sensoryFeedback(.success, trigger: lastTriggeredThreshold)
            .onDisappear {
                reset()
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    lastTriggeredThreshold = nil
                }

                dragOffset = value.translation

                let currentDragWidth = value.translation.width

                if currentDragWidth < -swipeThreshold {
                    if lastTriggeredThreshold != .left {
                        print("d")
                        lastTriggeredThreshold = .left
                    }
                } else if currentDragWidth > swipeThreshold {
                    if lastTriggeredThreshold != .right {
                        lastTriggeredThreshold = .right
                    }
                } else {
                    if lastTriggeredThreshold != nil {
                        lastTriggeredThreshold = nil
                    }
                }
            }
            .onEnded { value in
                let projectedEndWidth = value.translation.width +
                    value.predictedEndTranslation.width * predictionFactor

                if projectedEndWidth < -swipeThreshold {
                    onSwipeLeft()
                } else if projectedEndWidth > swipeThreshold {
                    onSwipeRight()
                }

                reset()

                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    dragOffset = .zero
                }
            }
    }

    private func reset() {
        isDragging = false
        lastTriggeredThreshold = nil
    }
}
