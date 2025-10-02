//
//  ArtworkManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/12/2024.
//

import SwiftUI

/// Manages artwork fetching and caching for media items.
///
/// `ArtworkManager` is a singleton actor that provides efficient artwork data
/// retrieval with intelligent caching and request deduplication. Each artwork
/// fetch uses its own connection to prevent buffer confusion during parallel loads.
actor ArtworkManager {
    static let shared = ArtworkManager()

    private let cache = NSCache<NSString, NSData>()

    /// Private initializer to enforce singleton pattern. Sets up the cache with
    /// a 64MB memory limit.
    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    /// Fetches artwork data for a given file, handling caching.
    ///
    /// This function first checks the in-memory cache for the artwork. If not
    /// found, it creates a new connection to fetch the data from the MPD server.
    ///
    /// - Parameters:
    ///   - file: The file path of the artwork to fetch.
    ///   - shouldCache: A Boolean indicating whether to store the fetched data
    ///                  in the in-memory cache. Defaults to `true`.
    /// - Returns: The artwork data.
    /// - Throws: An error if the artwork data cannot be fetched.
    func get(for file: String, shouldCache: Bool = true) async throws -> Data {
        try Task.checkCancellation()

        if shouldCache, let data = cache.object(forKey: file as NSString) {
            return data as Data
        }

        let data = try await ConnectionManager<ArtworkMode>.artwork()
            .getArtworkData(for: file)

        if shouldCache {
            cache.setObject(data as NSData, forKey: file as NSString, cost: data.count)
        }

        return data
    }
}
