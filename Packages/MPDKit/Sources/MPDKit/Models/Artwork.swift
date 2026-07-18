//
//  Artwork.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import ImageIO

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
    #if canImport(UIKit)
        /// The platform-specific image.
        public let image: UIImage?
    #elseif canImport(AppKit)
        /// The platform-specific image.
        public let image: NSImage?
    #endif

    // XXX: Use `file` if this ever gets added to MPD's protocol.
    // See: https://github.com/MusicPlayerDaemon/MPD/issues/2397
    /// A hash of the original image data, used for equality comparisons.
    public let hash: Int

    #if canImport(UIKit)
        /// Creates a new artwork container.
        /// - Parameters:
        ///   - image: The platform-specific image.
        ///   - hash: A hash of the original image data.
        public init(image: UIImage?, hash: Int) {
            self.image = image
            self.hash = hash
        }

    #elseif canImport(AppKit)
        /// Creates a new artwork container.
        /// - Parameters:
        ///   - image: The platform-specific image.
        ///   - hash: A hash of the original image data.
        public init(image: NSImage?, hash: Int) {
            self.image = image
            self.hash = hash
        }
    #endif

    #if canImport(UIKit)
        /// Decodes artwork data into a bitmap no larger than the given pixel
        /// size.
        ///
        /// `UIImage(data:)` defers decoding to render time and decodes at the
        /// embedded artwork's full resolution regardless of the display size.
        /// This decodes eagerly via ImageIO instead, bounded by
        /// `maxPixelSize`, so displaying a thumbnail costs thumbnail-sized
        /// memory and no decode happens during rendering.
        ///
        /// - Parameters:
        ///   - data: The compressed artwork data.
        ///   - maxPixelSize: The maximum width or height of the decoded
        ///                   bitmap, in pixels.
        /// - Returns: The decoded image, or `nil` if the data is not a valid
        ///            image.
        public static func downsampledImage(from data: Data, maxPixelSize:
            Int) -> UIImage?
        {
            guard let cgImage = downsampledCGImage(from: data, maxPixelSize:
                maxPixelSize)
            else {
                return nil
            }

            return UIImage(cgImage: cgImage)
        }

    #elseif canImport(AppKit)
        /// Decodes artwork data into a bitmap no larger than the given pixel
        /// size.
        ///
        /// `NSImage(data:)` defers decoding to render time and decodes at the
        /// embedded artwork's full resolution regardless of the display size.
        /// This decodes eagerly via ImageIO instead, bounded by
        /// `maxPixelSize`, so displaying a thumbnail costs thumbnail-sized
        /// memory and no decode happens during rendering.
        ///
        /// - Parameters:
        ///   - data: The compressed artwork data.
        ///   - maxPixelSize: The maximum width or height of the decoded
        ///                   bitmap, in pixels.
        /// - Returns: The decoded image, or `nil` if the data is not a valid
        ///            image.
        public static func downsampledImage(from data: Data, maxPixelSize:
            Int) -> NSImage?
        {
            guard let cgImage = downsampledCGImage(from: data, maxPixelSize:
                maxPixelSize)
            else {
                return nil
            }

            return NSImage(cgImage: cgImage, size: .zero)
        }
    #endif

    /// Decodes and downsamples image data via ImageIO.
    private static func downsampledCGImage(from data: Data, maxPixelSize:
        Int) -> CGImage?
    {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData,
                                                       sourceOptions)
        else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary

        return CGImageSourceCreateThumbnailAtIndex(source, 0,
                                                   thumbnailOptions)
    }
}
