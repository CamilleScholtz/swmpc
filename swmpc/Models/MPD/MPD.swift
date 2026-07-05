//
//  MPD.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import Foundation
import MPDKit
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

    /// The task forwarding connection-state events into `StateManager`.
    @ObservationIgnored private var stateObservationTask: Task<Void, Never>?

    init() {
        database = DatabaseManager(state: state)
        queue = QueueManager(state: state)
        playlists = PlaylistManager(state: state)

        status.setupRemoteCommands()

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
    ///
    /// - Returns: `true` if a new connection was established, `false` if a
    ///            connection already existed or the task was cancelled.
    private func connect() async -> Bool {
        while !Task.isCancelled {
            do {
                guard let states = try await ConnectionManager.idle.connect()
                else {
                    return false
                }

                observeStates(states)
                return true
            } catch {
                state.error = error

                try? await Task.sleep(for: .seconds(2))
            }
        }

        return false
    }

    /// Forwards connection-state events from the idle connection's stream
    /// into `StateManager`.
    private func observeStates(_ states: AsyncStream<ConnectionState>) {
        stateObservationTask?.cancel()
        stateObservationTask = Task { [weak self] in
            for await state in states {
                guard let self else { return }

                self.state.connectionState = state

                switch state {
                case let .failed(reason):
                    self.state.error = NSError(
                        domain: "MPD",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Connection failed: \(reason)"],
                    )
                case let .waiting(reason, _):
                    self.state.error = NSError(
                        domain: "MPD",
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Trying to connect: \(reason)"],
                    )
                case .ready, .cancelled:
                    self.state.error = nil
                case .preparing, .setup:
                    break
                }
            }
        }
    }

    /// The main update loop that maintains the MPD connection and state.
    ///
    /// This method continuously listens for changes using the idle command
    /// and updates the appropriate subsystems when changes are detected.
    /// Whenever a new connection is established — initially or after a
    /// reconnect — all managers are re-synced, since changes that happened
    /// while disconnected are never reported by idle events.
    private func updateLoop() async {
        while !Task.isCancelled {
            if await connect() {
                try? await database.set()
                try? await queue.set()
                try? await playlists.set()
                try? await status.set()
                try? await outputs.set()
            }

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
            } catch {
                // A cancelled loop must not tear down the connection: a
                // successor loop (see `reinitialize`) may already own a new
                // one.
                guard !Task.isCancelled else {
                    return
                }

                await ConnectionManager.idle.disconnect()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    /// Performs updates based on MPD idle events.
    ///
    /// A single idle response can report multiple changed subsystems; each
    /// one is mapped to the manager that mirrors it. The status is refreshed
    /// at most once, even when several subsystems that affect it changed.
    ///
    /// - Parameter events: The changed subsystems reported by the idle
    ///                     command.
    /// - Throws: An error if any update operation fails.
    private func performUpdates(for events: [IdleEvent]) async throws {
        if events.contains(.playlists) {
            try await playlists.set()
        }

        if events.contains(.database) {
            try await database.set()
        }

        if events.contains(.queue) {
            try await queue.set()
        }

        if !Set(events).isDisjoint(with: [.queue, .player, .options, .mixer]) {
            try await status.set()
        }

        if events.contains(.output) {
            try await outputs.set()
        }
    }
}
