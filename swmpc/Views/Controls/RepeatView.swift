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

    var body: some View {
        AsyncButton {
            try await ConnectionManager.command {
                try await $0.repeat(!(mpd.status.isRepeat ?? false))
            }
        } label: {
            ZStack {
                Image(systemSymbol: .repeat)
                    .padding(Layout.Padding.medium)

                Circle()
                    .fill(Color(.accent))
                    .frame(width: Layout.Size.dotIndicator, height: Layout.Size.dotIndicator)
                    .offset(y: 12)
                    .opacity(mpd.status.isRepeat ?? false ? 1 : 0)
            }
            .contentShape(Circle())
        }
        .styledButton()
        .help(mpd.status.isRepeat ?? false ? "Disable repeat mode" : "Enable repeat mode")
    }
}
