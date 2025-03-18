//
//  BackButtonView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import SwiftUI

struct BackButtonView: View {
    @Environment(\.navigator) private var navigator

    @State private var isHovering = false

    var body: some View {
        Image(systemSymbol: .chevronBackward)
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovering ? Color(.secondarySystemFill) : .clear)
            )
            .padding(.top, 12)
            .animation(.interactiveSpring, value: isHovering)
            .onHover { value in
                isHovering = value
            }
            .onTapGesture {
                navigator.back()
            }
    }
}
