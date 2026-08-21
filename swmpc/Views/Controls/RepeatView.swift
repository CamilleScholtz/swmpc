//
//  RepeatView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

import ButtonKit
import MPDKit
import SwiftUI

struct RepeatView: View {
    @Environment(MPD.self) private var mpd

    @State private var feedback = ActionFeedback()

    private var isRepeat: Bool {
        mpd.status.isRepeat ?? false
    }

    var body: some View {
        AsyncButton {
            let value = !isRepeat
            feedback.play(.selection(value ? .on : .off))

            try await ConnectionManager.command {
                try await $0.repeat(value)
            }
        } label: {
            ZStack {
                Image(systemSymbol: .repeat)
                    .padding(Layout.Padding.medium)

                Circle()
                    .fill(Color(.accent))
                    .frame(width: Layout.Size.dotIndicator, height: Layout.Size.dotIndicator)
                    .offset(y: 12)
                    .opacity(isRepeat ? 1 : 0)
            }
            .contentShape(Circle())
        }
        .styledButton()
        .accessibilityLabel(Text("Repeat"))
        .accessibilityValue(isRepeat ? Text("On") : Text("Off"))
        .accessibilityAddTraits(isRepeat ? .isSelected : [])
        .actionFeedback(feedback)
    }
}
