//
//  NowPlayingWidgetView.swift
//  widget
//
//  Created by Camille Scholtz on 09/12/2025.
//

import SFSafeSymbols
import SwiftUI

struct NowPlayingWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        NowPlayingWidgetView(entry: entry)
    }
}

struct NowPlayingWidgetView: View {
    let entry: NowPlayingEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            artworkView

            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .mask(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .black, location: 0.3),
                            .init(color: .black.opacity(0), location: 1.0),
                        ]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(entry.artist)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .topTrailing) {
            Image(systemSymbol: .opticaldiscFill)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .padding(15)
        }
    }

    @ViewBuilder
    private var artworkView: some View {
        if let artwork = entry.artwork {
            #if os(iOS)
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            #elseif os(macOS)
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            #endif
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.2))

                Image(systemSymbol: .musicNote)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
