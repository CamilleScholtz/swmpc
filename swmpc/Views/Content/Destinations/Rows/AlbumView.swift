//
//  AlbumView.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import ButtonKit
import SFSafeSymbols
import SwiftUI

struct AlbumView: View {
    @Environment(MPD.self) private var mpd
    @Environment(NavigationManager.self) private var navigator

    private let album: Album

    init(for album: Album) {
        self.album = album
    }

    @State private var artwork: PlatformImage?
    @State private var artworkTask: Task<Void, Never>?

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
                ArtworkView(image: artwork, aspectRatioMode: .fill)
                    .frame(width: Layout.RowHeight.album, height: Layout.RowHeight.album)
                    .cornerRadius(Layout.CornerRadius.small)
                    .animation(.easeInOut(duration: 0.15), value: artwork != nil)
                    .overlay(
                        Color.clear
                            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Layout.CornerRadius.small))
                            .mask(
                                RadialGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.4),
                                        .init(color: .black, location: 1.0),
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 50,
                                ),
                            ),
                    )
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 1)

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
                    try? await ConnectionManager.command().play(album)
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
            .onChange(of: album) { previous, value in
                guard previous != value else {
                    return
                }

                artworkTask?.cancel()
                artwork = nil
            }
            .task(id: album, priority: .high) {
                artworkTask?.cancel()

                artworkTask = Task {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else {
                        return
                    }

                    let newArtwork = try? await album.artwork()
                    guard !Task.isCancelled, newArtwork != nil else {
                        return
                    }

                    artwork = newArtwork
                }

                await artworkTask?.value
            }
    }
}
