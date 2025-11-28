//
//  ArtistView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SwiftUI

struct ArtistView: View, Equatable {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    private let artist: Artist

    init(for artist: Artist) {
        self.artist = artist
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.artist == rhs.artist
    }

    @State private var albumCount: Int = 0

    var body: some View {
        HStack(spacing: Layout.Spacing.large) {
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: Layout.RowHeight.artist, height: Layout.RowHeight.artist)
                .overlay(
                    ZStack {
                        Text(artist.name.initials)
                            .font(.system(size: 18))
                            .fontDesign(.rounded)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Color.clear
                            .glassEffect(.clear, in: Circle())
                            .mask(
                                RadialGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.0),
                                        .init(color: .black, location: 1.0),
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 45,
                                ),
                            )
                    },
                )
                .shadow(color: .black.opacity(0.15), radius: 8, y: 1)

            VStack(alignment: .leading) {
                Text(artist.name)
                    .font(.headline)
                    .foregroundColor(mpd.status.song?.isBy(artist) ?? false ? .accentColor : .primary)
                    .lineLimit(2)

                Text(albumCount == 1 ? "1 album" : "\(albumCount) albums")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            navigator.navigate(to: ContentDestination.artist(artist))
        }
        .contextMenu {
            ContextMenuView(for: artist)
        }
        .task(id: artist, priority: .medium) {
            guard !Task.isCancelled else {
                return
            }

            albumCount = await (try? artist.getAlbums().count) ?? 0
        }
    }
}
