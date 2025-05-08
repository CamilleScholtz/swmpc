//
//  View+MiniPlayer.swift
//  swmpc
//
//  Created by Camille Scholtz on 5/8/2025.
//

import SwiftUI

extension View {
    /// Adds a miniature player that can be expanded to a full-screen player view,
    /// similar to Apple Music's mini player.
    ///
    /// This modifier adds a miniplayer that appears at the bottom of the view and can be
    /// expanded to a full-screen player with swipe gestures.
    ///
    /// - Returns: A view with the mini player overlay.
    @ViewBuilder
    func withPopover() -> some View {
        ZStack {
            self
        }
        .overlay(alignment: .bottom) {
            CompactMiniplayer()
                .padding(.bottom, 55)
        }
    }
}

private struct CompactMiniplayer: View {
    @Environment(MPD.self) private var mpd
    
    @State private var expanded: Bool = false
    @State private var draggedOffset: CGFloat = 0.0
    @State private var artwork: PlatformImage?

    @Namespace private var namespace

    var body: some View {
        ZStack {
            if expanded {
                // Full screen player when expanded
                DetailView(
                    artwork: artwork,
                    isPopupOpen: $expanded,
                    isMiniplayer: true,
                    animationNamespace: namespace
                )
                .background(.background)
                .transition(.opacity)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow dragging down
                            if value.translation.height > 0 {
                                draggedOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 100 ||
                                value.predictedEndLocation.y - value.location.y > 80
                            {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    expanded = false
                                }
                            }

                            draggedOffset = 0
                        }
                )
                .offset(y: draggedOffset)
            } else if mpd.status.song != nil {
                // Compact player when collapsed and a song is available
                HStack(spacing: 8) {
                    // Album artwork
                    artworkView
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .matchedGeometryEffect(
                            id: PlayerMatchedGeometry.artwork,
                            in: namespace
                        )

                    // Title and artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mpd.status.song?.title ?? "Not Playing")
                            .lineLimit(1)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let artist = mpd.status.song?.artist {
                            Text(artist)
                                .lineLimit(1)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Play/pause button
                    Button {
                        Task {
                            try await ConnectionManager.command().pause(mpd.status.isPlaying)
                        }
                    } label: {
                        Image(systemName: mpd.status.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Next button
                    Button {
                        Task {
                            try await ConnectionManager.command().next()
                        }
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                .padding(.horizontal)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            // Only allow dragging up
                            if value.translation.height < 0 {
                                draggedOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height < -20 ||
                                value.predictedEndLocation.y - value.location.y < -40
                            {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    expanded = true
                                }
                            }

                            draggedOffset = 0
                        }
                )
                .offset(y: draggedOffset * 0.5) // Apply some resistance to the drag
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        expanded = true
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: mpd.status.song != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: expanded)
        .onAppear {
            Task {
                await fetchArtwork()
            }
        }
        .onChange(of: mpd.status.song) {
            Task {
                await fetchArtwork()
            }
        }
    }

    private var artworkView: some View {
        Group {
            if let artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    }
            }
        }
    }

    private func fetchArtwork() async {
        guard let song = mpd.status.song else {
            artwork = nil
            return
        }

        guard let data = try? await ArtworkManager.shared.get(for: song, shouldCache: true) else {
            artwork = nil
            return
        }

        artwork = PlatformImage(data: data)
    }
}
