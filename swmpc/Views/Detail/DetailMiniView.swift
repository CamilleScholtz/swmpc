//
//  DetailMiniView.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/07/2025.
//

import ButtonKit
import SFSafeSymbols
import SwiftUI

struct DetailMiniView: View {
    @Environment(MPD.self) private var mpd

    let artwork: Artwork?

    var body: some View {
        HStack(spacing: Layout.Spacing.small) {
            ArtworkView(image: artwork?.image, aspectRatioMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.small / 1.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(mpd.status.song?.title ?? "No song playing")
                    .font(.subheadline)
                    .lineLimit(1)

                Text(mpd.status.song?.artist ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    }
}
