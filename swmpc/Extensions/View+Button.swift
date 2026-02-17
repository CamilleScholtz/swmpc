//
//  View+Button.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/03/2025.
//

import SwiftUI

extension View {
    /// Adds hover (macOS) and press effects to a Button's content view.
    /// Provides immediate visual feedback on press for both macOS and iOS.
    /// Includes a minimum visual press duration.
    ///
    /// - Parameters:
    ///   - hoverScale: The scale factor to apply on hover (macOS only,
    ///                 default: 1.2)
    ///   - pressScale: The scale factor to apply when pressed (default: 0.9,
    ///                 automatically adjusted by -0.05 on iOS)
    ///   - minimumPressDuration: The minimum time the press effect should
    ///                           visually last (default: 0.1 seconds)
    /// - Returns: A view with hover and press effects applied.
    func styledButton(
        hoverScale: CGFloat = 1.2,
        pressScale: CGFloat = 0.9,
        minimumPressDuration: TimeInterval = 0.1,
    ) -> some View {
        #if os(iOS)
            let pressScale = pressScale - 0.05
        #endif

        return modifier(StyledButtonModifier(
            hoverScale: hoverScale,
            pressScale: pressScale,
            minimumPressDuration: minimumPressDuration,
        ))
    }
}

/// Custom button style that provides visual press feedback with a minimum duration.
/// Ensures the press effect is visible for at least the specified duration,
/// even for quick taps.
struct PressedButtonStyle: ButtonStyle {
    let scale: CGFloat
    let minimumDuration: TimeInterval

    @State private var isVisuallyPressed: Bool = false
    @State private var pressEndTask: Task<Void, Never>? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isVisuallyPressed ? scale : 1.0)
            .animation(.interactiveSpring, value: isVisuallyPressed)
            .onChange(of: configuration.isPressed) { _, isPhysicallyPressed in
                if isPhysicallyPressed {
                    pressEndTask?.cancel()
                    pressEndTask = nil

                    if !isVisuallyPressed {
                        isVisuallyPressed = true
                    }
                } else {
                    guard isVisuallyPressed else {
                        return
                    }

                    pressEndTask = Task {
                        do {
                            try await Task.sleep(for: .seconds(minimumDuration))
                            try Task.checkCancellation()

                            isVisuallyPressed = false
                        } catch is CancellationError {
                            // NO-OP
                        } catch {
                            isVisuallyPressed = false
                        }

                        pressEndTask = nil
                    }
                }
            }
            .onAppear {
                if configuration.isPressed, !isVisuallyPressed {
                    isVisuallyPressed = true
                }
            }
            .onDisappear {
                pressEndTask?.cancel()
            }
    }
}

/// View modifier that combines hover and press effects for buttons.
/// On macOS: Applies hover scale effect.
/// On iOS: Adds additional press handling for drag gestures.
private struct StyledButtonModifier: ViewModifier {
    let hoverScale: CGFloat
    let pressScale: CGFloat
    let minimumPressDuration: TimeInterval

    #if os(iOS)
        @State private var isVisuallyPressed: Bool = false
        @State private var pressEndTask: Task<Void, Never>? = nil
    #elseif os(macOS)
        @State private var isHovering = false
    #endif

    func body(content: Content) -> some View {
        content
            .buttonStyle(
                PressedButtonStyle(scale: pressScale,
                                   minimumDuration: minimumPressDuration),
            )
        #if os(iOS)
            .scaleEffect(isVisuallyPressed ? pressScale : 1.0)
            .animation(.interactiveSpring, value: isVisuallyPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isVisuallyPressed {
                            pressEndTask?.cancel()
                            pressEndTask = nil
                            isVisuallyPressed = true
                        }
                    }
                    .onEnded { _ in
                        guard isVisuallyPressed else {
                            return
                        }

                        pressEndTask = Task {
                            do {
                                try await Task.sleep(for: .seconds(
                                    minimumPressDuration,
                                ))
                                try Task.checkCancellation()

                                isVisuallyPressed = false
                            } catch {
                                isVisuallyPressed = false
                            }
                            pressEndTask = nil
                        }
                    },
            )
            .onDisappear {
                pressEndTask?.cancel()
            }
        #elseif os(macOS)
            .scaleEffect(isHovering ? hoverScale : 1.0)
            .animation(.interactiveSpring, value: isHovering)
            .onHover { value in
                isHovering = value
            }
        #endif
    }
}
