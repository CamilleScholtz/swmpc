//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import MPDKit
import SwiftUI

/// A protocol for media items that can have associated artwork.
///
/// Types conforming to `Artworkable` can fetch artwork images from the MPD
/// server. Artwork is automatically cached and deduplicated by content hash.
protocol Artworkable {
    /// Fetches the artwork for this media item, decoded to fit the given size
    /// in points.
    ///
    /// - Parameter pointSize: The largest dimension, in points, at which the
    ///                        artwork will be displayed.
    /// - Returns: An `Artwork` instance if artwork is available, or `nil` if no
    ///            artwork is found.
    /// - Throws: An error if the artwork retrieval fails.
    func artwork(fitting pointSize: CGFloat) async throws -> Artwork?
}

extension Artworkable where Self: Mediable {
    /// Default implementation that fetches artwork from the MPD server using
    /// the media item's file.
    ///
    /// This implementation uses the `ArtworkManager` to retrieve artwork,
    /// decoded and downsampled to the display size so that showing a
    /// thumbnail costs thumbnail-sized memory. The returned `Artwork`
    /// includes a hash of the image data for efficient equality comparisons.
    ///
    /// - Parameter pointSize: The largest dimension, in points, at which the
    ///                        artwork will be displayed.
    /// - Returns: An `Artwork` instance if artwork is available, or `nil` if no
    ///            artwork is found.
    /// - Throws: An error if the artwork retrieval fails.
    func artwork(fitting pointSize: CGFloat) async throws -> Artwork? {
        guard let (image, hash) = try await ArtworkManager.shared.image(
            for: file, fitting: pointSize)
        else {
            return nil
        }

        return Artwork(image: image, hash: hash)
    }
}

extension Album: Artworkable {}
extension Song: Artworkable {}

extension Artist {
    /// Fetches all albums by this artist from the MPD database.
    ///
    /// - Returns: An array of `Album` objects associated with this artist.
    /// - Throws: An error if the database query fails.
    func getAlbums() async throws -> [Album] {
        try await ConnectionManager.command {
            try await $0.getAlbums(by: self, from: .database)
        }
    }
}

extension Album {
    /// Fetches all songs in this album from the MPD database.
    ///
    /// - Returns: An array of `Song` objects belonging to this album.
    /// - Throws: An error if the database query fails.
    func getSongs() async throws -> [Song] {
        try await ConnectionManager.command {
            try await $0.getSongs(in: self, from: .database)
        }
    }
}
