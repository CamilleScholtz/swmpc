//
//  DetailMiniView.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/07/2025.
//

import ButtonKit
import Noise
import SFSafeSymbols
import SwiftUI

struct DetailMiniView: View {
    @Environment(MPD.self) private var mpd

    @State private var artwork: PlatformImage?

    #if os(iOS)
        private var progress: Float {
            guard let elapsed = mpd.status.elapsed,
                  let duration = mpd.status.song?.duration,
                  duration > 0
            else {
                return 0
            }

            return Float(elapsed / duration)
        }
    #endif

    var body: some View {
        HStack {
            ArtworkView(image: artwork)
//                .frame(width: 50, height: 50)
                .cornerRadius(4)

            VStack {
                Text(mpd.status.song?.title ?? "No song playing")
                    .font(.subheadline)

                Text(mpd.status.song?.artist ?? "")
                    .font(.caption)
            }

            Spacer()

//            PauseView()
//            NextView()
        }
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                artwork = nil
                return
            }

            artwork = try? await song.artwork()
        }
    }
}
