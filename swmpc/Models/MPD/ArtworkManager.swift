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
    private var tasks: [String: Task<Data, Error>] = [:]

    /// Private initializer to enforce singleton pattern. Sets up the cache with
    /// a 64MB memory limit.
    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    /// Fetches artwork data for a given file, handling caching and debouncing.
    ///
    /// This function first checks the in-memory cache for the artwork. If not
    /// found, it debounces the request by waiting 20ms before fetching. If a new
    /// request comes in for the same file during this delay, the previous request
    /// is cancelled. This prevents excessive fetching during fast scrolling.
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

        let task = tasks[file, default: Task {
            defer { tasks[file] = nil }

            try await Task.sleep(for: .milliseconds(25))
            try Task.checkCancellation()

            let data = try await ConnectionManager.artwork {
                try await $0.getArtworkData(for: file)
            }

            if shouldCache {
                cache.setObject(data as NSData, forKey: file as NSString, cost: data.count)
            }

            return data
        }]

        return try await task.value
    }
}
