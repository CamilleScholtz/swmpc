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
        VStack(alignment: .leading, spacing: 7) {
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

            PlayerProgressView()
        }

        VStack {
            #if os(iOS)
                HStack(alignment: .center, spacing: 20) {
                    RepeatView()

                    HStack(spacing: 15) {
                        PreviousView()
                        PauseView()
                        NextView()
                    }

                    RandomView()
                }
                .asyncButtonStyle(.pulse)
            #elseif os(macOS)
                HStack(alignment: .center, spacing: 40) {
                    RepeatView()

                    HStack(spacing: 20) {
                        PreviousView()
                        PauseView()
                        NextView()
                    }

                    RandomView()
                }
                .asyncButtonStyle(.pulse)
            #endif
        }
    }
}
