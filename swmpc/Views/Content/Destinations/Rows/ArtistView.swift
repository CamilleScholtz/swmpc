//
//  ArtistView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SwiftUI

struct ArtistView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    private let artist: Artist

    init(for artist: Artist) {
        self.artist = artist
    }

    @State private var albumCount: Int = 0

    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(.secondarySystemFill), location: 0.0),
                        .init(color: Color(.secondarySystemFill).opacity(0.7), location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom,
                ))
                .frame(width: 50, height: 50)
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
        .task(id: artist, priority: .high) {
            albumCount = await (try? artist.getAlbums().count) ?? 0
        }
    }
}
