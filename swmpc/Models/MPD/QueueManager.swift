//
//  QueueManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/11/2024.
//

import SwiftUI

/// Manages the MPD queue, handling song operations.
@Observable
final class QueueManager {
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
    @MainActor
    func set(idle: Bool = false, force _: Bool = false) async throws {
        state.isLoading = true
        defer { state.isLoading = false }

        songs = try await idle
            ? ConnectionManager.idle.getSongs(from: .queue)
            : ConnectionManager.command().getSongs(from: .queue)
    }
}
