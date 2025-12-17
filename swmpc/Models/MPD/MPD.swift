//
//  MPD.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import Foundation
import MPDKit
import Network
import Observation

/// The main MPD client class that manages the connection and state
/// synchronization.
///
/// This class orchestrates the connection to the MPD server and maintains the
/// current state through its child objects: Status, Database, and Queue. It
/// uses the idle command to listen for changes and automatically updates the
/// relevant state when changes occur.
@Observable final class MPD {
    /// The state manager handling loading and connection states.
    let state = StateManager()

    /// The MPD status manager, tracking playback state and current song.
    let status = StatusManager()

    /// The MPD database manager, handling music library queries.
    let database: DatabaseManager

    /// The MPD queue manager, handling queue operations.
    let queue: QueueManager

    /// The playlist manager, handling playlist operations.
    let playlists: PlaylistManager

    /// The output manager, handling audio outputs.
    let outputs = OutputManager()

    /// The streaming manager, handling audio streaming from httpd output.
    let streaming = StreamingManager()

    /// The background task that maintains the connection and listens for
    /// changes.
    @ObservationIgnored private var updateLoopTask: Task<Void, Never>?

    /// The task handling the current reinitialization, if any.
    @ObservationIgnored private var reinitializeTask: Task<Void, Never>?

    init() {
        database = DatabaseManager(state: state)
        queue = QueueManager(state: state)
        playlists = PlaylistManager(state: state)

        updateLoopTask = Task { [weak self] in
            await self?.updateLoop()
        }
    }

    /// Reinitializes the MPD connection with new settings.
    func reinitialize() async {
        reinitializeTask?.cancel()

        reinitializeTask = Task { [weak self] in
            self?.updateLoopTask?.cancel()
            self?.updateLoopTask = nil

            await ConnectionManager.idle.disconnect()

            self?.state.error = nil

            try? await Task.sleep(for: .seconds(1))

            guard !Task.isCancelled else { return }

            self?.updateLoopTask = Task { [weak self] in
                await self?.updateLoop()
            }
        }

        await reinitializeTask?.value
    }

    /// Establishes a connection to the MPD server.
    ///
    /// This method attempts to connect to the MPD server repeatedly until
    /// successful or the task is cancelled. On failure, it waits 2 seconds
    /// before retrying.
    private func connect() async {
        while !Task.isCancelled {
            do {
                try await ConnectionManager.idle.connect { [weak self] _,
                    state in
                    Task { @MainActor [weak self] in
                        self?.state.connectionState = state

                        switch state {
                        case let .failed(details):
                            self?.state.error = NSError(
                                domain: "MPD",
                                code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Connection failed: \(details.localizedDescription)"],
                            )
                        case let .waiting(details):
                            self?.state.error = NSError(
                                domain: "MPD",
                                code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Trying to connect: \(details.localizedDescription)"],
                            )
                        case .cancelled:
                            self?.state.error = nil
                        case .ready:
                            self?.state.error = nil
                        case .preparing, .setup:
                            break
                        @unknown default:
                            break
                        }
                    }
                }

                return
            } catch {
                state.error = error

                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// The main update loop that maintains the MPD connection and state.
    ///
    /// This method establishes the initial connection, loads the initial state,
    /// and then continuously listens for changes using the idle command. When
    /// changes are detected, it updates the appropriate subsystems.
    private func updateLoop() async {
        await connect()

        try? await database.set()
        try? await queue.set()
        try? await playlists.set()
        try? await status.set()
        try? await outputs.set()

        while !Task.isCancelled {
            await connect()

            do {
                let changes = try await ConnectionManager.idle.idleForEvents(mask: [
                    .database,
                    .playlists,
                    .queue,
                    .player,
                    .options,
                    .mixer,
                    .output,
                ])

                try? await performUpdates(for: changes)
            } catch is ConnectionManagerError {
                await ConnectionManager.idle.disconnect()
                try? await Task.sleep(for: .seconds(2))
            } catch {
                continue
            }
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
    private func performUpdates(for event: IdleEvent) async throws {
        switch event {
        case .playlists:
            try await playlists.set()
        case .database:
            try await database.set()
        case .queue:
            try await queue.set()
            try await status.set()
        case .player:
            try await status.set()
        case .options:
            try await status.set()
        case .mixer:
            try await status.set()
        case .output:
            try await outputs.set()
        }
    }
}
