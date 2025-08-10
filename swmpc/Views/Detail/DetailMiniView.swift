//
//  DetailMiniView.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/07/2025.
//

import ButtonKit
import SFSafeSymbols
import SwiftUI

// MARK: - Layout Constants

private extension Layout.CornerRadius {
    static let detailMiniArtwork: CGFloat = 4
}

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
                .cornerRadius(Layout.CornerRadius.detailMiniArtwork)

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
