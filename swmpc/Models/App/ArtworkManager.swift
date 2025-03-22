//
//  ArtworkManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 22/12/2024.
//

import SwiftUI

actor ArtworkManager {
    static let shared = ArtworkManager()

    private let cache = NSCache<NSURL, NSData>()
    private var tasks: [URL: (task: Task<Data, Error>, isPrefetch: Bool)] = [:]

    private init() {
        cache.totalCostLimit = 50 * 1024 * 1024
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

        if let existing = tasks[media.url] {
            return try await existing.task.value
        }

        let task = Task<Data, Error>(priority: .high) { [shouldCache] in
            defer { removeTask(for: media.url) }

            let data = try await ConnectionManager.artwork().getArtworkData(for:
                media.url)
            if shouldCache {
                storeInCache(data, for: media.url)
            }

            return data
        }

        tasks[media.url] = (task, false)
        return try await task.value
    }

    /// Prefetches artwork for multiple media items.
    ///
    /// - Parameter mediaItems: The media items for which to prefetch the
    ///                         artwork.
    /// - Throws: An error if the artwork data could not be fetched.
    func prefetch(for mediaItems: [any Playable]) {
        cancelPrefetchOutsideRange(mediaItems)
        
        let itemsToFetch = mediaItems.filter { media in
            cache.object(forKey: media.url as NSURL) == nil &&
                !tasks.keys.contains(media.url)
        }

        for media in itemsToFetch {
            let task = Task<Data, Error>(priority: .utility) {
                defer { self.removeTask(for: media.url) }

                let data = try await ConnectionManager.artwork().getArtworkData(
                    for: media.url)
                self.storeInCache(data, for: media.url)

                return data
            }

            tasks[media.url] = (task, true)
        }
    }

    /// Cancels all prefetching tasks.
    func cancelPrefetching() {
        var remainingTasks = [URL: (task: Task<Data, Error>, isPrefetch:
            Bool)]()

        for (url, taskInfo) in tasks {
            if taskInfo.isPrefetch {
                taskInfo.task.cancel()
            } else {
                remainingTasks[url] = taskInfo
            }
        }

        tasks = remainingTasks
    }

    /// Cancels prefetch tasks for media items not in the given prefetch range.
    ///
    /// - Parameter prefetchRange: The media items that should be in the prefetch range.
    private func cancelPrefetchOutsideRange(_ prefetchRange: [any Playable]) {
        let prefetchURLs = Set(prefetchRange.map { $0.url })
        var remainingTasks = [URL: (task: Task<Data, Error>, isPrefetch: Bool)]()
        
        for (url, taskInfo) in tasks {
            if taskInfo.isPrefetch && !prefetchURLs.contains(url) {
                taskInfo.task.cancel()
            } else {
                remainingTasks[url] = taskInfo
            }
        }
        
        tasks = remainingTasks
    }
    
    private func storeInCache(_ data: Data, for url: URL) {
        cache.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
    }

    private func removeTask(for url: URL) {
        tasks.removeValue(forKey: url)
    }
}
