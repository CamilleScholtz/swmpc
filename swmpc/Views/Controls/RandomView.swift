//
//  RandomView.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/07/2025.
//

import ButtonKit
import SwiftUI

struct RandomView: View {
    @Environment(MPD.self) private var mpd

    var body: some View {
        AsyncButton {
            try await ConnectionManager.command().random(!(mpd.status.isRandom ?? false))
        } label: {
            ZStack {
                Image(systemSymbol: .shuffle)
                    .padding(10)

                Circle()
                    .fill(Color(.accent))
                    .frame(width: 3.5, height: 3.5)
                    .offset(y: 12)
                    .opacity(mpd.status.isRandom ?? false ? 1 : 0)
            }
            .contentShape(Circle())
        }
        .styledButton()
    }
}
