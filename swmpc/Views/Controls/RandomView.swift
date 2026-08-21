//
//  RandomView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

import ButtonKit
import MPDKit
import SwiftUI

struct RandomView: View {
    @Environment(MPD.self) private var mpd

    @State private var feedback = ActionFeedback()

    private var isRandom: Bool {
        mpd.status.isRandom ?? false
    }

    var body: some View {
        AsyncButton {
            let value = !isRandom
            feedback.play(.selection(value ? .on : .off))

            try await ConnectionManager.command {
                try await $0.random(value)
            }
        } label: {
            ZStack {
                Image(systemSymbol: .shuffle)
                    .padding(Layout.Padding.medium)

                Circle()
                    .fill(Color(.accent))
                    .frame(width: Layout.Size.dotIndicator, height: Layout.Size.dotIndicator)
                    .offset(y: 12)
                    .opacity(isRandom ? 1 : 0)
            }
            .contentShape(Circle())
        }
        .styledButton()
        .accessibilityLabel(Text("Shuffle"))
        .accessibilityValue(isRandom ? Text("On") : Text("Off"))
        .accessibilityAddTraits(isRandom ? .isSelected : [])
        .actionFeedback(feedback)
    }
}
