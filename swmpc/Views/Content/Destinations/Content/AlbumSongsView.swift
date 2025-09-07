//
//  AlbumSongsView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SwiftUI

private extension Layout.Padding {
    static let artwork: CGFloat = 18
    static let playingIndicator: CGFloat = 10
}

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
            HStack(spacing: Layout.Spacing.large) {
                ZStack {
                    ZStack(alignment: .bottom) {
                        ArtworkView(image: artwork)
                            .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.medium))
                            .shadow(color: .black.opacity(0.2), radius: Layout.Padding.small, y: 4)
                            .frame(width: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: Layout.CornerRadius.medium)
                                    .fill(.clear)
                                    .glassEffect(.clear, in: .rect(cornerRadius: Layout.CornerRadius.medium))
                                    .mask(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: Layout.CornerRadius.medium)

                                            RoundedRectangle(cornerRadius: Layout.CornerRadius.medium)
                                                .scale(0.9)
                                                .blur(radius: 8)
                                                .blendMode(.destinationOut)
                                        },
                                    ),
                            )
                            .overlay(
                                ZStack(alignment: .bottomLeading) {
                                    Color.clear
                                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Layout.CornerRadius.medium))
                                        .mask(
                                            LinearGradient(
                                                gradient: Gradient(stops: [
                                                    .init(color: .black, location: 0.3),
                                                    .init(color: .black.opacity(0), location: 1.0),
                                                ]),
                                                startPoint: .bottom,
                                                endPoint: .top,
                                            ),
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.medium))

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
                                    .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.rounded))
                                    .padding(Layout.Padding.playingIndicator)
                                }
                                .opacity(mpd.status.song?.isIn(album) ?? false ? 1 : 0)
                                .animation(.interactiveSpring, value: mpd.status.song?.isIn(album) ?? false),
                            )
                    }

                    #if os(macOS)
                        if isHovering, !(mpd.status.song?.isIn(album) ?? false) {
                            AsyncButton {
                                try await ConnectionManager.command().play(album)
                            } label: {
                                Image(systemSymbol: .playFill)
                                    .font(.title2)
                                    .foregroundStyle(.foreground)
                                    .padding(Layout.Padding.medium)
                                    .glassEffect(.regular.tint(.accent.opacity(0.5)))
                                    .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
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

                    Button {
                        navigator.navigate(to: ContentDestination.artist(album.artist))
                    } label: {
                        Text(album.artist.name)
                            .font(.system(size: 12))
                            .fontWeight(.semibold)
                            .lineLimit(2)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Copy Artist Name", systemSymbol: .documentOnDocument) {
                            album.artist.name.copyToClipboard()
                        }
                    }

                    if let songs {
                        let flat = songs.values.flatMap(\.self)
                        Text(
                            String(localized: "\(flat.count) \(flat.count == 1 ? "song" : "songs")")
                                + " • "
                                + (flat.reduce(0) { $0 + $1.duration }.humanTimeString),
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.bottom, Layout.Spacing.medium)
        }
        .mediaRowStyle()
        .task {
            artwork = try? await album.artwork()

            let fetchedSongs = await (try? album.getSongs()) ?? []
            songs = Dictionary(grouping: fetchedSongs, by: { $0.disc })
        }

        if let songs {
            Section {
                ForEach(songs.keys.sorted(), id: \.self) { disc in
                    if songs.keys.count > 1 {
                        Text("Disc \(String(disc))")
                            .font(.headline)
                            .padding(.top, disc == songs.keys.sorted().first ? 0 : 10)
                            .mediaRowStyle()
                    }

                    ForEach(songs[disc] ?? []) { song in
                        SongView(for: song, source: .database)
                            .equatable()
                            .mediaRowStyle()
                    }
                }
            }
        }
    }
}
