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

    private let cache = NSCache<NSURL, NSData>()
    private var tasks: [URL: Task<Data, Error>] = [:]

    /// Private initializer to enforce singleton pattern. Sets up the cache with
    /// a 64MB memory limit.
    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    /// Fetches artwork data for a given URL, handling caching and request
    /// deduplication.
    ///
    /// This function first checks the in-memory cache for the artwork. If not
    /// found, it checks if a fetch task for the same URL is already in
    /// progress. If so, it awaits the result of that task. Otherwise, it
    /// creates a new task to fetch the data from the network.
    ///
    /// - Parameters:
    ///   - url: The URL of the artwork to fetch.
    ///   - shouldCache: A Boolean indicating whether to store the fetched data
    ///                  in the in-memory cache. Defaults to `true`.
    /// - Returns: The artwork data.
    /// - Throws: An error if the artwork data cannot be fetched.
    func get(for url: URL, shouldCache: Bool = true) async throws ->
        Data
    {
        try Task.checkCancellation()

        if shouldCache, let data = cache.object(forKey: url as NSURL) {
            return data as Data
        }

        if let existingTask = tasks[url] {
            return try await existingTask.value
        }

        let task = createFetchTask(for: url, priority: .high,
                                   shouldCache: shouldCache)
        tasks[url] = task

        defer { tasks.removeValue(forKey: url) }

        return try await task.value
    }

    /// Creates and returns a new `Task` to fetch artwork data for a specific
    /// URL.
    ///
    /// The created task creates a new connection for each fetch operation,
    /// retrieves the artwork data, and properly cleans up the connection.
    /// The task also handles caching if `shouldCache` is true.
    ///
    /// - Parameters:
    ///   - url: The URL of the artwork to fetch.
    ///   - priority: The `TaskPriority` for the fetch operation.
    ///   - shouldCache: A Boolean indicating whether to cache the fetched data
    ///                  upon successful completion.
    /// - Returns: A `Task` that will produce the artwork `Data` or throw an
    ///            `Error`.
    private func createFetchTask(for url: URL, priority: TaskPriority,
                                 shouldCache: Bool) -> Task<Data, Error>
    {
        Task(priority: priority) {
            try Task.checkCancellation()

            let connection = try await ConnectionManager<ArtworkMode>.artwork()

            do {
                let data = try await connection.getArtworkData(for: url)
                await connection.disconnect()

                try Task.checkCancellation()

                if shouldCache {
                    storeInCache(data, for: url)
                }

                return data
            } catch {
                await connection.disconnect()
                throw error
            }
        }
    }

    /// Stores artwork data in the cache.
    /// - Parameters:
    ///   - data: The artwork data to cache.
    ///   - url: The URL key for the cached data.
    private func storeInCache(_ data: Data, for url: URL) {
        cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
    }
}
