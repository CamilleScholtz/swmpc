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
    /// The state manager, used to indicate when data is being fetched.
    @ObservationIgnored private let state: StateManager

    init(state: StateManager) {
        self.state = state
    }

    /// The songs in the queue.
    private(set) var songs: [Song] = []

    /// Sets/refreshes the queue contents.
    ///
    /// - Parameters:
    ///   - idle: Whether to use the idle connection.
    /// - Throws: An error if the queue could not be loaded.
    func set(idle: Bool = false) async throws {
        defer { state.isLoading = false }

        songs = try await idle
            ? ConnectionManager.idle.getSongs(from: .queue)
            : ConnectionManager.command {
                try await $0.getSongs(from: .queue)
            }
    }
}
