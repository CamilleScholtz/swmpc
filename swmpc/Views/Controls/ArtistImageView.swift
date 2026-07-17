//
//  ArtistImageView.swift
//  swmpc
//
//  Created by Camille Scholtz on 12/07/2026.
//

import MPDKit
import SwiftUI

/// A circular artist image with the artist's initials as placeholder and
/// fallback.
///
/// The image URL is resolved via `ArtistArtworkManager` (Apple Music
/// catalog).
struct ArtistImageView: View {
    /// A dedicated session so artist images get a proper disk cache,
    /// independent of the shared `URLCache`.
    private static let imageSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 16 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024,
        )

        return URLSession(configuration: configuration)
    }()

    private let artist: Artist
    private let size: CGFloat
    private let initialsFontSize: CGFloat

    #if os(iOS)
        private let glassMaskInset = Layout.Padding.large
    #elseif os(macOS)
        private let glassMaskInset = Layout.Padding.small
    #endif

    init(for artist: Artist, size: CGFloat, initialsFontSize: CGFloat) {
        self.artist = artist
        self.size = size
        self.initialsFontSize = initialsFontSize
    }

    @State private var url: URL?

    var body: some View {
        Circle()
            .fill(Color(.tertiarySystemFill))
            .frame(width: size, height: size)
            .overlay {
                ZStack {
                    Text(artist.name.initials)
                        .font(.system(size: initialsFontSize))
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    if let url {
                        artistImage(for: url)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    }

                    Color.clear
                        .glassEffect(.clear, in: Circle())
                        .mask {
                            RadialGradient(
                                stops: [
                                    .init(color: .clear, location: 0.4),
                                    .init(color: .black, location: 1.0),
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size - glassMaskInset,
                            )
                        }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: url)
            .task(id: artist, priority: .medium) {
                url = await ArtistArtworkManager.shared.info(for: artist)?.url
            }
    }

    /// The remote artist image. On OS 26 the request-based `AsyncImage` and
    /// the dedicated cache session are unavailable, so images fall back to the
    /// shared `URLCache`.
    @ViewBuilder
    private func artistImage(for url: URL) -> some View {
        if #available(iOS 27.0, macOS 27.0, *) {
            AsyncImage(request: URLRequest(
                url: url,
                cachePolicy: .returnCacheDataElseLoad,
            )) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.clear
            }
            .asyncImageURLSession(Self.imageSession)
        } else {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.clear
            }
        }
    }
}
