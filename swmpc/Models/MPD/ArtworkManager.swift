//
//  ArtworkManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/12/2024.
//

import MPDKit
import SwiftUI

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
    private var fileToHash: [String: Int] = [:]

    /// Caches artwork data by hash, deduplicating identical artwork.
    private let cache = NSCache<NSNumber, NSData>()

    /// Tracks in-flight fetch tasks to deduplicate concurrent requests.
    private var tasks: [String: Task<(Data, Int), Error>] = [:]

    /// Private initializer to enforce singleton pattern. Sets up the cache with
    /// a 64MB memory limit.
    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024
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

        if let hash = fileToHash[file],
           let data = cache.object(forKey: NSNumber(value: hash))
        {
            return (data as Data, hash)
        }

        let task = tasks[file, default: Task {
            defer { tasks[file] = nil }

            let data = try await ConnectionManager.artwork {
                try await $0.getArtworkData(for: file)
            }

            let hash = data.hashValue
            fileToHash[file] = hash

            if cache.object(forKey: NSNumber(value: hash)) == nil {
                cache.setObject(data as NSData, forKey: NSNumber(value: hash),
                                cost: data.count)
            }

            return (data, hash)
        }]

        return try await task.value
    }
}
