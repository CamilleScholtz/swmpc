//
//  View+Hover.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

extension View {
    /// Adds a hover effect to the view, applying animations when the cursor hovers over the view.
    /// - Parameters:
    ///   - scale: The scale factor to apply when hovered (default: 1.05)
    ///   - animation: The animation to use (default: .interactiveSpring)
    /// - Returns: A view with hover effects applied
    func hoverEffect(
        scale: CGFloat = 1.2,
        animation: Animation = .interactiveSpring()
    ) -> some View {
        modifier(HoverEffectModifier(scale: scale, animation: animation))
    }
}

/// A view modifier that applies hover effects
struct HoverEffectModifier: ViewModifier {
    let scale: CGFloat
    let animation: Animation

    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
        #if os(macOS)
        .scaleEffect(isHovering ? scale : 1.0)
        .animation(animation, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
    }
}
