//
//  QueueManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/11/2024.
//

import MPDKit
import Observation

/// Manages the MPD queue, handling song operations.
@Observable final class QueueManager {
    /// The songs in the queue.
    private(set) var songs: [Song] = []

    /// Sets/refreshes the queue contents.
    ///
    /// - Parameter connection: The connection to load over.
    /// - Throws: An error if the queue could not be loaded.
    func set<Mode: ConnectionMode>(on connection: ConnectionManager<Mode>)
        async throws
    {
        songs = try await connection.getSongs(from: .queue)
    }
}
