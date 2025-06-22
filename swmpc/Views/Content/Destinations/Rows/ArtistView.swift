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

    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(.secondarySystemFill), location: 0.0),
                        .init(color: Color(.secondarySystemFill).opacity(0.7), location: 1.0),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                ))
            #if os(iOS)
                .frame(width: 60, height: 60)
            #elseif os(macOS)
                .frame(width: 50, height: 50)
            #endif
                .overlay(
                    Text(artist.name.initials)
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
        .contentShape(Rectangle())
        .onTapGesture {
            navigator.navigate(to: ContentDestination.artist(artist))
        }
        .contextMenu {
            @AppStorage(Setting.simpleMode) var simpleMode = false
            if !simpleMode {
                ArtistQueueToggleButton(artist: artist)
                Divider()
            }

            Button("Copy Artist Name") {
                artist.name.copyToClipboard()
            }
        }
    }
}

struct ArtistQueueToggleButton: View {
    @Environment(MPD.self) private var mpd

    let artist: Artist

    @State private var songs: [Song]?

    private var actuallyInQueue: Bool {
        guard let songs else {
            return false
        }

        let urls = Set(mpd.queue.internalMedia.map(\.url))
        return songs.contains { urls.contains($0.url) }
    }

    var body: some View {
        AsyncButton(actuallyInQueue ? "Remove All by Artist from Queue" : "Add All by Artist to Queue") {
            if actuallyInQueue {
                try await ConnectionManager.command().removeFromQueue(artist: artist)
            } else {
                try await ConnectionManager.command().addToQueue(artist: artist)
            }
        }
        .task(id: artist) {
            songs = try? await ConnectionManager.command().getSongs(using: .database, for: artist)
        }
    }
}
