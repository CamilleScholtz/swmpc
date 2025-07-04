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
/// Features:
/// - In-memory caching using NSCache with automatic memory management
/// - Deduplication of concurrent requests for the same artwork
/// - Connection pooling for efficient network utilization
actor ArtworkManager {
    static let shared = ArtworkManager()

    private let cache = NSCache<NSURL, NSData>()
    private var tasks: [URL: Task<Data, Error>] = [:]

    /// Private initializer to enforce singleton pattern. Sets up the cache with
    /// a 64MB memory limit.
    private init() {
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    /// Fetches the artwork data for a given media.
    ///
    /// - Parameters:
    ///     - media: The media for which to fetch the artwork.
    ///     - shouldCache: Whether or not to cache the fetched data.
    /// - Returns: The artwork data.
    /// - Throws: An error if the artwork data could not be fetched.
    func get(for media: any Mediable, shouldCache: Bool = true) async throws ->
        Data
    {
        if shouldCache, let data = cache.object(forKey: media.url as NSURL) {
            return data as Data
        }

        if let existingTask = tasks[media.url] {
            return try await existingTask.value
        }

        let task = createFetchTask(for: media.url, priority: .high,
                                   shouldCache: shouldCache)
        tasks[media.url] = task

        return try await task.value
    }

    /// Creates a new Task responsible for fetching artwork data.
    /// Handles connection pooling, data fetching, caching, and task removal.
    ///
    /// - Parameters:
    ///     - url: The URL of the artwork to fetch.
    ///     - priority: The priority of the task.
    ///     - shouldCache: Whether or not to cache the fetched data.
    private func createFetchTask(for url: URL, priority: TaskPriority,
                                 shouldCache: Bool) -> Task<Data, Error>
    {
        Task(priority: priority) {
            defer { removeTask(for: url) }

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

    /// Removes a completed or failed task from the active tasks dictionary.
    /// - Parameter url: The URL key for the task to remove.
    private func removeTask(for url: URL) {
        tasks.removeValue(forKey: url)
    }
}

/// Manages a pool of reusable connections for artwork fetching.
/// This actor implements connection pooling to optimize network resource usage.
///
/// ## Features
/// - Maintains up to 8 concurrent connections
/// - Reuses existing connections when possible
/// - Automatically validates connections before reuse
/// - Queues requests when all connections are in use
/// - Handles connection lifecycle management
///
/// ## Implementation Details
/// The pool uses a double-ended queue (Deque) for efficient connection management
/// and maintains a separate queue for tasks waiting for available connections.
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
    /// empty and the maximum number of connections are active,the calling task
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
    /// This method is called when a connection fails and cannot be returned to the pool.
    /// If there are tasks waiting for connections and we're below the maximum limit,
    /// a new connection is created to replace the discarded one.
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
