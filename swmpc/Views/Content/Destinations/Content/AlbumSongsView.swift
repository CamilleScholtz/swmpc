//
//  AlbumSongsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SwiftUI

struct AlbumSongsView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator
    @Environment(\.colorScheme) private var colorScheme

    init(for album: Album) {
        _album = State(initialValue: album)
    }

    @State private var album: Album
    @State private var artwork: PlatformImage?
    @State private var songs: [Int: [Song]]?

    #if os(macOS)
        @State private var isHovering = false
    #endif

    var body: some View {
        Section {
            HStack(spacing: 15) {
                ZStack {
                    ZStack(alignment: .bottom) {
                        ArtworkView(image: artwork)
                            .frame(width: 80)
                            .blur(radius: 9.5)
                            .offset(y: 4)
                            .saturation(1.5)
                            .blendMode(colorScheme == .dark ? .softLight : .normal)
                            .opacity(0.5)

                        ArtworkView(image: artwork)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                            .frame(width: 100)
                            .overlay(
                                ZStack(alignment: .bottomLeading) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 100)
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

                                    HStack(spacing: 5) {
                                        Image(systemSymbol: .playFill)
                                        Text("Playing")
                                    }
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.white)
                                    .cornerRadius(100)
                                    .padding(10)
                                }
                                .opacity(mpd.status.media?.id == album.id ? 1 : 0)
                                .animation(.interactiveSpring, value: mpd.status.media?.id == album.id)
                            )
                    }

                    #if os(macOS)
                        if isHovering, mpd.status.media?.id != album.id {
                            AsyncButton {
                                guard mpd.status.media?.id != album.id else {
                                    return
                                }

                                try await ConnectionManager.command().play(album)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(.accent)
                                        .frame(width: 60, height: 60)
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 60, height: 60)

                                    Image(systemSymbol: .playFill)
                                        .font(.title)
                                        .foregroundColor(.white)
                                }
                            }
                            .styledButton(hoverScale: 1.05)
                            .asyncButtonStyle(.pulse)
                        }
                    #endif
                }
                #if os(macOS)
                .onHover { value in
                    withAnimation(.interactiveSpring) {
                        isHovering = value
                    }
                }
                #endif
                .contextMenu {
                    ContextMenuView(for: album)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(album.title)
                        .font(.system(size: 18))
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                        .lineLimit(3)

                    AsyncButton {
                        guard let artist = try? await mpd.database.get(for: album, using: .artist) as? Artist else {
                            throw ViewError.missingData
                        }

                        navigator.navigate(to: ContentDestination.artist(artist))
                    } label: {
                        Text(album.artist)
                            .font(.system(size: 12))
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .onTapGesture {
                                Task(priority: .userInitiated) {
                                    guard let artist = try? await mpd.database.get(for: album, using: .artist) as? Artist else {
                                        return
                                    }

                                    navigator.navigate(to: ContentDestination.artist(artist))
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .asyncButtonStyle(.pulse)
                    .contextMenu {
                        Button("Copy Artist Name") {
                            album.artist.copyToClipboard()
                        }
                    }

                    if let songs {
                        let flat = songs.values.flatMap(\.self)
                        Text(
                            String(localized: "\(flat.count) \(flat.count == 1 ? "song" : "songs")")
                                + " • "
                                + (flat.reduce(0) { $0 + $1.duration }.humanTimeString)
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.bottom, 15 + 7.5)
            #if os(iOS)
                .listRowInsets(.init(top: 7.5, leading: 15, bottom: 15 + 7.5, trailing: 15))
            #elseif os(macOS)
                .listRowInsets(.init(top: 15, leading: 7.5, bottom: 7.5, trailing: 7.5))
            #endif
                .task {
                    artwork = try? await album.artwork()
                    songs = await Dictionary(grouping: (try? ConnectionManager.command().getSongs(in: album, from: .database)) ?? [], by: { $0.disc })
                }
        }
        #if os(macOS)
        .frame(width: 310)
        #endif
        .overlay(
            Rectangle()
            #if os(iOS)
                .foregroundColor(Color(.secondarySystemFill))
            #elseif os(macOS)
                .foregroundColor(colorScheme == .dark ? .black : Color(.secondarySystemFill))
                .offset(x: -15)
            #endif
                .frame(height: 1),
            alignment: .bottom
        )

        if let songs {
            Section {
                ForEach(songs.keys.sorted(), id: \.self) { disc in
                    if songs.keys.count > 1 {
                        Text("Disc \(String(disc))")
                            .font(.headline)
                            .padding(.top, disc == songs.keys.sorted().first ? 0 : 10)
                    }

                    ForEach(songs[disc] ?? []) { song in
                        SongView(for: song)
                    }
                }
            }
        }
    }
}
