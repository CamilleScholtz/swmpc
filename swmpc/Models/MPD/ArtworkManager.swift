//
//  ArtworkManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/12/2024.
//

import DequeModule
import SwiftUI

/// Manages artwork fetching and caching for media items.
///
/// `ArtworkManager` is a singleton actor that provides efficient artwork data
/// retrieval with intelligent caching and request deduplication. It integrates
/// with `ArtworkConnectionPool` to manage network connections efficiently.
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
    /// The created task encapsulates the entire network operation, including:
    /// 1. Acquiring a connection from the `ArtworkConnectionPool`.
    /// 2. Fetching the artwork data using the connection.
    /// 3. Releasing or discarding the connection based on the outcome.
    /// 4. Caching the data if `shouldCache` is true.
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

            var connection: ConnectionManager<ArtworkMode>?
            do {
                connection = try await ArtworkConnectionPool.shared
                    .acquireConnection()
                guard let acquiredConnection = connection else {
                    throw ConnectionManagerError.connectionSetupFailed
                }

                try Task.checkCancellation()

                let data = try await acquiredConnection.getArtworkData(for: url)

                await ArtworkConnectionPool.shared.releaseConnection(
                    acquiredConnection)
                connection = nil

                try Task.checkCancellation()

                if shouldCache {
                    storeInCache(data, for: url)
                }

                return data
            } catch {
                if let failedConnection = connection {
                    await ArtworkConnectionPool.shared.discardConnection(
                        failedConnection)
                }

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

/// Manages a pool of reusable connections for artwork fetching.
///
/// `ArtworkConnectionPool` is a singleton actor that implements connection
/// pooling to optimize network resource usage and reduce connection setup
/// overhead. It maintains a pool of validated connections that can be reused
/// across multiple artwork fetch operations.
actor ArtworkConnectionPool {
    static let shared = ArtworkConnectionPool()

    /// The maximum number of connections allowed to be active (checked out)
    /// concurrently.
    private let maxSize = 8

    /// Available connections ready for immediate reuse.
    private var pool: Deque<ConnectionManager<ArtworkMode>> = Deque()

    /// How many connections are currently checked out and in use.
    private var activeConnectionsCount = 0

    /// Tasks waiting for a connection because the pool was empty and the limit
    /// was reached.
    private var waiters: Deque<CheckedContinuation<ConnectionManager<ArtworkMode>,
        Error>> = Deque()

    /// Private initializer to enforce singleton pattern.
    private init() {}

    /// Acquires a connection from the pool.
    ///
    /// If a connection is available in the pool, it's returned immediately. If
    /// the pool is empty but the maximum number of active connections hasn't
    /// been reached, a new connection is created and returned. If the pool is
    /// empty and the maximum number of connections are active, the calling task
    /// will be suspended until a connection is released.
    ///
    /// - Returns: A connected `ConnectionManager<ArtworkMode>`.
    /// - Throws: A `ConnectionManagerError` if creating or validating a
    ///           connection fails.
    func acquireConnection() async throws -> ConnectionManager<ArtworkMode> {
        while true {
            try Task.checkCancellation()

            if let connection = pool.popFirst() {
                do {
                    try await connection.ping()
                    activeConnectionsCount += 1

                    return connection
                } catch {
                    await connection.disconnect()
                    continue
                }
            }

            if activeConnectionsCount < maxSize {
                activeConnectionsCount += 1
                do {
                    let connection = ConnectionManager<ArtworkMode>()
                    try await connection.connect()

                    return connection
                } catch {
                    activeConnectionsCount -= 1
                    throw ConnectionManagerError.connectionSetupFailed
                }
            }

            return try await withCheckedThrowingContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    /// Returns a connection to the pool or passes it directly to a waiting
    /// task.
    ///
    /// - Parameter connection: The `ConnectionManager<ArtworkMode>` to release.
    func releaseConnection(_ connection: ConnectionManager<ArtworkMode>) {
        activeConnectionsCount -= 1

        if let waiter = waiters.popFirst() {
            waiter.resume(returning: connection)
            activeConnectionsCount += 1
        } else {
            pool.append(connection)
        }
    }

    /// Discards a failed connection and optionally creates a replacement.
    ///
    /// This method is called when a connection fails and cannot be returned to
    /// the pool. If there are tasks waiting for connections and we're below the
    /// maximum limit, a new connection is created to replace the discarded one.
    ///
    /// - Parameter connection: The failed connection to discard.
    func discardConnection(_ connection: ConnectionManager<ArtworkMode>) async {
        activeConnectionsCount -= 1
        await connection.disconnect()

        if !waiters.isEmpty, activeConnectionsCount < maxSize {
            activeConnectionsCount += 1

            do {
                let connection = ConnectionManager<ArtworkMode>()
                try await connection.connect()

                if let waiter = waiters.popFirst() {
                    waiter.resume(returning: connection)
                } else {
                    activeConnectionsCount -= 1
                    pool.append(connection)
                }
            } catch {
                activeConnectionsCount -= 1
            }
        }
    }
}
