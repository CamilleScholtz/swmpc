//
//  ArtworkManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/12/2024.
//

import Foundation
import MPDKit
import Synchronization

/// A cache of decoded artwork images that is safe to read from any isolation.
///
/// `NSCache` is documented as safe to use from multiple threads but isn't
/// marked `Sendable`, so this wrapper vouches for it.
private final nonisolated class ImageCache: @unchecked Sendable {
    private let cache = NSCache<NSString, PlatformImage>()

    /// Creates a cache holding at most `totalCostLimit` bytes of images.
    init(totalCostLimit: Int) {
        cache.totalCostLimit = totalCostLimit
    }

    /// The image stored under a key, if it hasn't been evicted.
    func image(forKey key: NSString) -> PlatformImage? {
        cache.object(forKey: key)
    }

    /// Stores an image under a key, at the given cost in bytes.
    func setImage(_ image: PlatformImage, forKey key: NSString, cost: Int) {
        cache.setObject(image, forKey: key, cost: cost)
    }
}

/// Manages artwork fetching and caching for media items.
///
/// `ArtworkManager` is a singleton actor that provides efficient artwork data
/// retrieval with intelligent caching and request deduplication. Each artwork
/// fetch uses its own connection to prevent buffer confusion during parallel
/// loads.
///
/// Caching is based on the hash of the artwork data, which deduplicates storage
/// when multiple songs share the same artwork (e.g., songs from the same
/// album).
actor ArtworkManager {
    static let shared = ArtworkManager()

    /// Maps file paths to their artwork data hash for quick lookups.
    ///
    /// Guarded by a mutex rather than by actor isolation so that a view can
    /// resolve a file to its already-decoded image while building a row, see
    /// ``cachedImage(for:fitting:)``.
    private nonisolated let fileToHash = Mutex<[String: Int]>([:])

    /// Caches compressed artwork data by hash, deduplicating identical
    /// artwork.
    private let dataCache = NSCache<NSNumber, NSData>()

    /// Caches decoded, downsampled images keyed by artwork hash and pixel
    /// size, so scrolling back to a row doesn't decode the same artwork
    /// again.
    private nonisolated let imageCache = ImageCache(totalCostLimit: 64 * 1024 * 1024)

    /// Tracks in-flight fetch tasks to deduplicate concurrent requests.
    private var tasks: [String: Task<(Data, Int), Error>] = [:]

    /// Private initializer to enforce singleton pattern. Sets up the data
    /// cache with a 64MB memory limit.
    private init() {
        dataCache.totalCostLimit = 64 * 1024 * 1024
    }

    /// Returns the artwork already decoded for a file at the given size.
    ///
    /// Unlike ``image(for:fitting:)`` this never fetches or decodes, so a
    /// view can call it while building a row to show artwork it has shown
    /// before instead of filling it in a frame later.
    ///
    /// - Parameters:
    ///   - file: The file path of the artwork.
    ///   - pointSize: The largest dimension, in points, at which the artwork
    ///                will be displayed.
    /// - Returns: The decoded image, or `nil` when it isn't cached.
    nonisolated func cachedImage(for file: String, fitting pointSize: CGFloat)
        -> PlatformImage?
    {
        guard let hash = fileToHash.withLock({ $0[file] }) else {
            return nil
        }

        return imageCache.image(forKey: Self.imageKey(hash: hash, fitting:
            pointSize))
    }

    /// The cache key identifying decoded artwork at a given display size.
    private nonisolated static func imageKey(hash: Int, fitting pointSize:
        CGFloat) -> NSString
    {
        "\(hash)-\(maxPixelSize(fitting: pointSize))" as NSString
    }

    /// The largest pixel dimension artwork is decoded to for a given display
    /// size.
    ///
    /// 3x covers the densest displays; the overshoot on 2x displays is cheap
    /// at these sizes.
    private nonisolated static func maxPixelSize(fitting pointSize: CGFloat)
        -> Int
    {
        Int(pointSize * 3)
    }

    /// Fetches artwork for a file and decodes it into a bitmap that fits the
    /// given size in points.
    ///
    /// The decode is bounded by the display size instead of the embedded
    /// artwork's resolution, and happens here — off the main actor — rather
    /// than lazily during rendering. Decoded images are cached by artwork
    /// hash and pixel size.
    ///
    /// - Parameters:
    ///   - file: The file path of the artwork to fetch.
    ///   - pointSize: The largest dimension, in points, at which the artwork
    ///                will be displayed.
    /// - Returns: A tuple containing the decoded image and the artwork data's
    ///            hash, or `nil` if the data is not a valid image.
    /// - Throws: An error if the artwork data cannot be fetched.
    func image(for file: String, fitting pointSize: CGFloat) async throws
        -> (image: PlatformImage, hash: Int)?
    {
        let (data, hash) = try await get(for: file)

        let key = Self.imageKey(hash: hash, fitting: pointSize)

        if let image = imageCache.image(forKey: key) {
            return (image, hash)
        }

        let maxPixelSize = Self.maxPixelSize(fitting: pointSize)

        guard let image = Artwork.downsampledImage(from: data, maxPixelSize:
            maxPixelSize)
        else {
            return nil
        }

        imageCache.setImage(image, forKey: key, cost: maxPixelSize *
            maxPixelSize * 4)

        return (image, hash)
    }

    /// Fetches artwork data for a given file, handling caching and request
    /// deduplication.
    ///
    /// This function uses a two-level lookup: first checking if we know the
    /// hash for this file, then looking up the data by hash. This ensures
    /// identical artwork from different files is stored only once.
    ///
    /// - Parameter file: The file path of the artwork to fetch.
    /// - Returns: A tuple containing the artwork data and its hash.
    /// - Throws: An error if the artwork data cannot be fetched.
    func get(for file: String) async throws -> (Data, Int) {
        try Task.checkCancellation()

        if let hash = fileToHash.withLock({ $0[file] }),
           let data = dataCache.object(forKey: NSNumber(value: hash))
        {
            return (data as Data, hash)
        }

        if let task = tasks[file] {
            return try await task.value
        }

        let task = Task {
            defer { tasks[file] = nil }

            let data = try await ConnectionManager.artwork {
                try await $0.getArtworkData(for: file)
            }

            let hash = data.hashValue
            fileToHash.withLock { $0[file] = hash }

            if dataCache.object(forKey: NSNumber(value: hash)) == nil {
                dataCache.setObject(data as NSData, forKey: NSNumber(value:
                    hash), cost: data.count)
            }

            return (data, hash)
        }
        tasks[file] = task

        return try await task.value
    }
}
