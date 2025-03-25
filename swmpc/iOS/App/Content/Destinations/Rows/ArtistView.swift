//
//  ArtistView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct ArtistView: View {
    @Environment(MPD.self) private var mpd
    @Environment(\.navigator) private var navigator

    private let artist: Artist

    init(for artist: Artist) {
        self.artist = artist
    }

    var body: some View {
        HStack(spacing: 5) {
            let initials = artist.name.split(separator: " ")
                .prefix(2)
                .compactMap(\.first)
                .map { String($0) }
                .joined()
                .uppercased()

            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(.secondarySystemFill), location: 0.0),
                        .init(color: Color(.secondarySystemFill).opacity(0.7), location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(initials)
                        .font(.system(size: 18))
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                )

            VStack(alignment: .leading) {
                Text(artist.name)
                    .font(.headline)
                    .foregroundColor(mpd.status.media?.id == artist.id ? .accentColor : .primary)
                    .lineLimit(2)
                Text(artist.albums?.count ?? 0 == 1 ? "1 album" : "\(artist.albums!.count) albums")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .id(artist)
        .contentShape(Rectangle())
        .onTapGesture {
            navigator.push(ContentDestination.artist(artist))
        }
    }
}
