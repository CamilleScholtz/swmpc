//
//  CurrentSongSnippetIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit
import SFSafeSymbols
import SwiftUI

/// Renders the interactive now-playing card shown by `CurrentSongIntent`.
///
/// The system re-performs this intent after every button tap in the snippet,
/// so all state is fetched fresh on each run.
struct CurrentSongSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Current Song Snippet"
    static let description = IntentDescription("Shows the currently playing song")

    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let data = try await command {
            try await $0.getStatusData()
        }

        var isFavorited = false
        var artwork: PlatformImage?
        if let song = data.song {
            let favorites = (try? await command {
                try await $0.getSongs(from: Source.favorites)
            }) ?? []

            isFavorited = favorites.contains { $0.file == song.file }
            artwork = (try? await ArtworkManager.shared.image(
                for: song.file,
                fitting: Self.artworkSize,
            ))?.image
        }

        return .result(view: CurrentSongSnippetView(
            song: data.song,
            isPlaying: data.state == .play,
            isFavorited: isFavorited,
            artwork: artwork,
        ))
    }

    static let artworkSize: CGFloat = 64
}

private struct CurrentSongSnippetView: View {
    let song: Song?
    let isPlaying: Bool
    let isFavorited: Bool
    let artwork: PlatformImage?

    var body: some View {
        if let song {
            VStack(spacing: Layout.Spacing.large) {
                HStack(spacing: Layout.Spacing.medium) {
                    ArtworkView(image: artwork, aspectRatioMode: .fill)
                        .frame(width: CurrentSongSnippetIntent.artworkSize,
                               height: CurrentSongSnippetIntent.artworkSize)
                        .clipShape(.rect(cornerRadius: Layout.CornerRadius.small))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title)
                            .font(.headline)
                            .lineLimit(1)

                        Text(song.artist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Text(song.album.title)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Button(intent: FavoriteSongIntent()) {
                        Image(systemSymbol: isFavorited ? .heartFill : .heart)
                            .foregroundStyle(isFavorited ? AnyShapeStyle(.red)
                                : AnyShapeStyle(.secondary))
                            .contentTransition(.symbolEffect(.replace.magic(fallback: .offUp)))
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Spacer()

                    Button(intent: PreviousSongIntent()) {
                        Image(systemSymbol: .backwardFill)
                    }

                    Spacer()

                    Button(intent: PlayPauseIntent()) {
                        Image(systemSymbol: isPlaying ? .pauseFill : .playFill)
                            .font(.title2)
                    }

                    Spacer()

                    Button(intent: NextSongIntent()) {
                        Image(systemSymbol: .forwardFill)
                    }

                    Spacer()
                }
                .font(.title3)
                .buttonStyle(.plain)
            }
            .padding(Layout.Padding.large)
        } else {
            Text("Nothing is currently playing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(Layout.Padding.large)
        }
    }
}
