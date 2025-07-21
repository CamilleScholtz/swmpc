//
//  QueueManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/11/2024.
//

import SwiftUI

/// Manages the MPD queue, handling song operations.
@Observable final class QueueManager {
    private let state: LoadingState

    init(state: LoadingState) {
        self.state = state
    }

    /// The songs in the queue.
    private(set) var songs: [Song] = []

    /// Sets/refreshes the queue contents.
    ///
    /// - Parameters:
    ///   - idle: Whether to use the idle connection.
    ///   - force: Whether to force the update.
    /// - Throws: An error if the queue could not be loaded.
    func set(idle: Bool = false, force _: Bool = false) async throws {
        defer { state.isLoading = false }

        songs = try await fetchSongs(idle: idle)
    }

    /// Fetches the songs from the MPD server.
    ///
    /// - Parameter idle: Whether to use the idle connection.
    /// - Returns: The songs from the MPD server.
    private func fetchSongs(idle: Bool) async throws -> [Song] {
        try await idle
            ? ConnectionManager.idle.getSongs(from: .queue)
            : ConnectionManager.command().getSongs(from: .queue)
    }
}
