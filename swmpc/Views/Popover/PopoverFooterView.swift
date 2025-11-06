//
//  PopoverFooterView.swift
//  swmpc
//
//  Created by Camille Scholtz on 29/03/2025.
//

import ButtonKit
import SwiftUI

struct PopoverFooterView: View {
    var body: some View {
        VStack(alignment: .center, spacing: Layout.Spacing.small) {
            PlayerProgressView(showTimestamps: false)
                .padding(.horizontal, Layout.Padding.large)
                .padding(.top, Layout.Padding.small)

            HStack(alignment: .center, spacing: 0) {
                RepeatView()
                    .offset(x: 10)

                Spacer()

                HStack(spacing: 2) {
                    PreviousView(size: 14)
                    PauseView(size: 24, button: false)
                        .frame(width: 20, height: 20)
                    NextView(size: 14)
                }

                Spacer()

                RandomView()
                    .offset(x: -10)
            }
            .asyncButtonStyle(.pulse)
            .frame(width: Layout.Size.popoverContentWidth)
            .offset(y: -4)
        }
        .frame(height: Layout.Size.popoverFooterHeight)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Layout.CornerRadius.medium))
    }
}
