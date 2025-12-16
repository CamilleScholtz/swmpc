//
//  Artwork.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

/// A container for artwork image data with equality based on content hash.
///
/// `Artwork` wraps a platform-specific image along with a hash of the original
/// image data. This allows efficient equality comparisons without re-encoding
/// the image, and ensures that identical artwork from different sources
/// (e.g., different songs from the same album) are considered equal.
public nonisolated struct Artwork: Equatable, Sendable {
    /// The platform-specific image.
    #if canImport(UIKit)
        public let image: UIImage?
    #elseif canImport(AppKit)
        public let image: NSImage?
    #endif

    // XXX: Use `file` if this ever gets added to MPD's protocol.
    // See: https://github.com/MusicPlayerDaemon/MPD/issues/2397
    /// A hash of the original image data, used for equality comparisons.
    public let hash: Int

    /// Creates a new artwork container.
    /// - Parameters:
    ///   - image: The platform-specific image.
    ///   - hash: A hash of the original image data.
    #if canImport(UIKit)
        public init(image: UIImage?, hash: Int) {
            self.image = image
            self.hash = hash
        }

    #elseif canImport(AppKit)
        public init(image: NSImage?, hash: Int) {
            self.image = image
            self.hash = hash
        }
    #endif

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hash == rhs.hash
    }
}
