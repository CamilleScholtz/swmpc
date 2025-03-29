//
//  View+ButtonStyle.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/03/2025.
//

import SwiftUI

struct PressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interactiveSpring, value: configuration.isPressed)
    }
}
