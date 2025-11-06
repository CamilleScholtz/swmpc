//
//  DetailFooterView.swift
//  swmpc
//
//  Created by Camille Scholtz on 18/03/2025.
//

import ButtonKit
import SwiftUI

struct DetailFooterView: View {
    @Environment(MPD.self) private var mpd

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.small - 0.5) {
            HStack(alignment: .center) {
                Text(mpd.status.song?.title ?? "No song playing")
                #if os(iOS)
                    .font(.system(size: 22))
                #elseif os(macOS)
                    .font(.system(size: 18))
                #endif
                    .fontWeight(.semibold)
                    .fontDesign(.rounded)

                Spacer()

                VolumeSliderView()
                    .offset(y: 1)

                FavoriteView()
                    .offset(x: 4, y: 1)
            }

            PlayerProgressView(showTimestamps: true)
        }

        VStack {
            #if os(iOS)
                HStack(alignment: .center, spacing: 20) {
                    RepeatView()

                    HStack(spacing: Layout.Spacing.large) {
                        PreviousView(size: 18)
                        PauseView(size: 30, button: true)
                        NextView(size: 18)
                    }

                    RandomView()
                }
                .asyncButtonStyle(.pulse)
            #elseif os(macOS)
                HStack(alignment: .center, spacing: 40) {
                    RepeatView()

                    HStack(spacing: 20) {
                        PreviousView(size: 18)
                        PauseView(size: 30, button: true)
                        NextView(size: 18)
                    }

                    RandomView()
                }
                .asyncButtonStyle(.pulse)
            #endif
        }
    }
}
