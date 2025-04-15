//
//  ArtworkManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/12/2024.
//

import DequeModule
import SwiftUI

actor ArtworkManager {
    static let shared = ArtworkManager()

    @AppStorage(Setting.isDemoMode) private var isDemoMode = false

    private let cache = NSCache<NSURL, NSData>()
    private var tasks: [URL: (task: Task<Data, Error>, isPrefetch: Bool)] = [:]

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
    func get(for media: any Playable, shouldCache: Bool = true) async throws ->
        Data
    {
        if shouldCache, let data = cache.object(forKey: media.url as NSURL) {
            return data as Data
        }

        if var existing = tasks[media.url] {
            if existing.isPrefetch {
                existing.isPrefetch = false
                tasks[media.url] = existing
            }

            return try await existing.task.value
        }

        if isDemoMode {
            return await MockData.shared.generateMockArtwork(for: media.url)
        }

        let task = createFetchTask(for: media.url, priority: .high,
                                   shouldCache: shouldCache)
        tasks[media.url] = (task: task, isPrefetch: false)

        return try await task.value
    }

    /// Prefetches artwork for multiple media items.
    ///
    /// - Parameter playables: The media items for which to prefetch the
    ///                         artwork.
    /// - Throws: An error if the artwork data could not be fetched.
    func prefetch(for playables: [any Playable]) {
        cancelPrefetchOutsideRange(playables)

        let itemsToFetch = playables.filter { media in
            cache.object(forKey: media.url as NSURL) == nil
                && tasks[media.url] == nil
        }

        for media in itemsToFetch {
            let task = createFetchTask(for: media.url, priority: .medium,
                                       shouldCache: true)
            tasks[media.url] = (task: task, isPrefetch: true)
        }
    }

    /// Cancels all prefetching tasks.
    func cancelPrefetching() {
        for (url, info) in tasks where info.isPrefetch {
            info.task.cancel()
            tasks.removeValue(forKey: url)
        }
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

    /// Cancels prefetch tasks for media items not in the given prefetch range.
    ///
    /// - Parameter playables: The media items that should be in the prefetch
    ///                        range.
    private func cancelPrefetchOutsideRange(_ playables: [any Playable]) {
        let urls = Set(playables.map(\.url))

        for (url, info) in tasks where info.isPrefetch {
            if !urls.contains(url) {
                info.task.cancel()
                tasks.removeValue(forKey: url)
            }
        }
    }

    private func storeInCache(_ data: Data, for url: URL) {
        cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
    }

    private func removeTask(for url: URL) {
        tasks.removeValue(forKey: url)
    }
}

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

    /// Disconnects all idle connections in the pool and cancels any waiting
    /// tasks.
    func reset() async {
        while let connection = pool.popFirst() {
            await connection.disconnect()
        }
        pool.removeAll()

        let currentWaiters = waiters
        waiters.removeAll()
        for waiter in currentWaiters {
            waiter.resume(throwing: CancellationError())
        }
    }
}
