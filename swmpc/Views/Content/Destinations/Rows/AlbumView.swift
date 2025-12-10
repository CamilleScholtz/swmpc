//
//  AlbumView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import MPDKit
import SFSafeSymbols
import SwiftUI

struct AlbumView: View, Equatable {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    private let album: Album

    init(for album: Album) {
        self.album = album
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.album == rhs.album
    }

    @State private var artwork: Artwork?

    #if os(iOS)
        @State private var isShowingContextMenu = false
    #elseif os(macOS)
        @State private var isHovering = false
        @State private var isHoveringArtwork = false
        @State private var hoverHandler = HoverTaskHandler()
    #endif

    var body: some View {
        HStack(spacing: Layout.Spacing.large) {
            ZStack {
                ArtworkView(image: artwork?.image, aspectRatioMode: .fill)
                    .frame(width: Layout.RowHeight.album, height: Layout.RowHeight.album)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.small))
                    .animation(.easeInOut(duration: 0.15), value: artwork != nil)
                    .overlay(
                        Color.clear
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Layout.CornerRadius.small))
                        #if os(iOS)
                            .mask(
                                RadialGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.4),
                                        .init(color: .black, location: 1.0),
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: Layout.RowHeight.album - Layout.Padding.large,
                                )
                            )
                        #elseif os(macOS)
                            .mask(
                                RadialGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.4),
                                        .init(color: .black, location: 1.0),
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: Layout.RowHeight.album - Layout.Padding.small,
                                )
                            )
                        #endif // swiftformat:options --trailing-commas multi-element-lists
                    )
                    .shadow(color: .black.opacity(0.2), radius: Layout.Padding.small)

                #if os(macOS)
                    Image(systemSymbol: .playFill)
                        .font(.title2)
                        .foregroundStyle(.foreground)
                        .padding(Layout.Padding.medium)
                        .glassEffect(.regular.tint(isHoveringArtwork ? .accent.opacity(0.5) : .clear).interactive())
                        .opacity(isHovering ? 1 : 0)
                        .animation(.interactiveSpring, value: isHovering)
                        .animation(.interactiveSpring, value: isHoveringArtwork)
                #endif
            }
            #if os(macOS)
            .onHover { value in
                withAnimation(.interactiveSpring) {
                    isHoveringArtwork = value
                }
            }
            #endif
            .onTapGesture {
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command {
                        try await $0.play(album)
                    }
                }
            }

            VStack(alignment: .leading) {
                Text(album.title)
                    .font(.headline)
                    .foregroundColor(mpd.status.song?.isIn(album) ?? false ? .accentColor : .primary)
                    .lineLimit(2)

                Text(album.artist.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        #if os(macOS)
            .onHoverWithDebounce(handler: hoverHandler) { hovering in
                withAnimation(.interactiveSpring) {
                    isHovering = hovering
                }
            }
        #endif
            .onTapGesture {
                navigator.navigate(to: ContentDestination.album(album))
            }
            .contextMenu {
                ContextMenuView(for: album)
            }
            .task(id: album, priority: .medium) {
                guard !Task.isCancelled else {
                    return
                }

                artwork = try? await album.artwork()
            }
    }
}
