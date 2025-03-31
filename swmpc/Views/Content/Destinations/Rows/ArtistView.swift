//
//  ArtistView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

struct ArtistView: View {
    @Environment(MPD.self) private var mpd
    @Environment(PathManager.self) private var pathManager

    private let artist: Artist
    private let sidebarDestination: SidebarDestination
    
    init(for artist: Artist, sidebarDestination: SidebarDestination = .artists) {
        self.artist = artist
        self.sidebarDestination = sidebarDestination
    }

    var body: some View {
        HStack(spacing: 15) {
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
        .id(artist.id)
        .contentShape(Rectangle())
        .onTapGesture {
            #if os(iOS)
                // Use the provided sidebar destination context
                let destination = ContentDestination.artist(artist)
                pathManager.navigate(to: destination, from: sidebarDestination)
            #elseif os(macOS)
                pathManager.contentPath.append(ContentDestination.artist(artist))
            #endif
        }
    }
}
