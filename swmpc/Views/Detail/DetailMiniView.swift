//
//  DetailMiniView.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/07/2025.
//

import ButtonKit
import MPDKit
import SFSafeSymbols
import SwiftUI

struct DetailMiniView: View {
    @Environment(MPD.self) private var mpd

    @State private var artwork: Artwork?

    private static let artworkSize: CGFloat = 32

    var body: some View {
        HStack(spacing: Layout.Spacing.small) {
            ArtworkView(image: artwork?.image, aspectRatioMode: .fill)
                .frame(width: Self.artworkSize, height: Self.artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.small / 1.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(mpd.status.song?.title ?? String(localized: "No song playing"))
                    .font(.headline.pointSize(14))
                    .lineLimit(1)

                Text(mpd.status.song?.artist ?? "")
                    .font(.caption)
                    .lineLimit(1)
            }

            Spacer()

            PauseView(size: 20, button: false)
                .offset(x: Layout.Spacing.medium)
            NextView(size: 16)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .padding(.horizontal, Layout.Padding.large)
        .task(id: mpd.status.song) {
            guard let song = mpd.status.song else {
                artwork = nil
                return
            }

            artwork = try? await song.artwork(fitting: Self.artworkSize)
        }
    }
}
