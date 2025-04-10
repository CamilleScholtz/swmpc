//
//  View+Button.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/03/2025.
//

import SwiftUI

extension View {
    /// Adds a hover effect to the view, applying animations when the cursor
    /// hovers over the view.
    /// - Parameters:
    ///   - scale: The scale factor to apply when hovered (default: 1.05)
    ///   - animation: The animation to use (default: .interactiveSpring)
    /// - Returns: A view with hover effects applied
    func button(
        scale: CGFloat = 1.2,
        animation: Animation = .interactiveSpring()
    ) -> some View {
        modifier(ButtonModifier(scale: scale, animation: animation))
    }
}

struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interactiveSpring, value: configuration.isPressed)
    }
}

struct ButtonModifier: ViewModifier {
    let scale: CGFloat
    let animation: Animation

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .buttonStyle(PressedButtonStyle())
        #if os(macOS)
            .scaleEffect(isHovering ? scale : 1.0)
            .animation(animation, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
        #endif
    }
}
