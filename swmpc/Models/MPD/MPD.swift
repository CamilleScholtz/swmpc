//
//  MPD.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

/// The main MPD client class that manages the connection and state
/// synchronization.
///
/// This class orchestrates the connection to the MPD server and maintains the
/// current state through its child objects: Status, Database, and Queue. It
/// uses the idle command to listen for changes and automatically updates the
/// relevant state when changes occur.
@Observable final class MPD {
    /// The MPD status manager, tracking playback state and current song.
    let status = Status()

    /// The MPD database manager, handling music library queries.
    let database = Database()

    /// The most recent connection or communication error, if any.
    var error: Error?

    /// The background task that maintains the connection and listens for
    /// changes.
    private var updateLoopTask: Task<Void, Never>?

    @MainActor
    init() {
        updateLoopTask = Task { [weak self] in
            await self?.updateLoop()
        }
    }

    deinit {
        updateLoopTask?.cancel()
    }

    /// Establishes a connection to the MPD server.
    ///
    /// This method attempts to connect to the MPD server repeatedly until
    /// successful or the task is cancelled. On failure, it waits 2 seconds
    /// before retrying.
    @MainActor
    private func connect() async {
        while !Task.isCancelled {
            do {
                try await ConnectionManager.idle.connect()
                error = nil

                return
            } catch {
                self.error = error
                status.state = nil

                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// The main update loop that maintains the MPD connection and state.
    ///
    /// This method establishes the initial connection, loads the initial state,
    /// and then continuously listens for changes using the idle command. When
    /// changes are detected, it updates the appropriate subsystems.
    @MainActor
    private func updateLoop() async {
        await connect()

        @AppStorage(Setting.simpleMode) var simpleMode = false
        if simpleMode {
            try? await ConnectionManager.command().loadPlaylist(nil)
        }

        try? await database.set(using: .album, idle: true)
        try? await status.set()
        try? await database.setPlaylists()

        while !Task.isCancelled {
            await connect()

            let changes = try? await ConnectionManager.idle.idleForEvents(mask: [
                .playlists,
                .queue,
                .player,
                .options,
            ])
            guard let changes else {
                continue
            }

            try? await performUpdates(for: changes)
        }
    }

    /// Performs updates based on MPD idle events.
    ///
    /// This method updates the appropriate subsystem based on the type of
    /// change:
    /// - `.playlists`: Updates the playlist list
    /// - `.database`: Updates the music database
    /// - `.queue`: Reloads the queue and posts a notification
    /// - `.player`: Updates the player status
    /// - `.options`: Updates the player status (includes random/repeat state)
    ///
    /// - Parameter change: The type of change reported by the idle command.
    /// - Throws: An error if any update operation fails.
    @MainActor
    private func performUpdates(for event: IdleEvent) async throws {
        switch event {
        case .playlists:
            try await database.setPlaylists()
        case .database:
            try await database.set()
        case .queue:
            try await status.set()

            NotificationCenter.default.post(name: .queueChangedNotification,
                                            object: nil)
        case .player:
            try await status.set()
        case .options:
            try await status.set()
        }
    }
}
