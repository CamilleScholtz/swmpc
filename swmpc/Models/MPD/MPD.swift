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

    /// The subsystems the update loop listens for changes on.
    private static let subsystems: [IdleEvent] = [
        .database,
        .playlists,
        .queue,
        .player,
        .options,
        .mixer,
        .output,
    ]

    /// The connection the update loop is currently listening on, if one is
    /// established.
    ///
    /// A connection manager is single-use: every attempt gets a fresh one, so
    /// a loop that is abandoned while parked on a dead read can never write
    /// into the buffer of its replacement.
    @ObservationIgnored private var connection: ConnectionManager<IdleMode>?

    /// The background task that maintains the connection and listens for
    /// changes.
    @ObservationIgnored private var updateLoopTask: Task<Void, Never>?

    init() {
        database = DatabaseManager(state: state)
        queue = QueueManager()
        playlists = PlaylistManager(state: state)

        status.setupRemoteCommands()

        start()
    }

    /// Discards the current connection and starts a fresh update loop.
    ///
    /// Nothing is awaited, so the swap is atomic on the main actor and two
    /// callers cannot interleave into two live loops. The outgoing loop is
    /// cancelled but not waited on: it may be parked on a read that never
    /// returns, and since it no longer owns `connection` it can do no harm on
    /// its way out.
    func reinitialize() {
        updateLoopTask?.cancel()

        if let connection {
            self.connection = nil
            Task { await connection.disconnect() }
        }

        state.error = nil
        state.connectionState = nil
        state.protocolVersion = nil

        start()
    }

    /// Brings all manager state up to date and verifies the idle connection
    /// is still alive.
    ///
    /// Intended for when the app returns to the foreground: while the app was
    /// suspended, the idle connection may have died without the socket ever
    /// reporting it, leaving the update loop parked on a read that never
    /// completes. The managers are refreshed over a single command connection
    /// first, so the UI is current immediately, then the idle connection is
    /// probed — and replaced outright if it fails to answer.
    func resync() async {
        guard let connection else {
            return
        }

        try? await ConnectionManager.command { [self] command in
            try await status.set(on: command)
            try await queue.set(on: command)
            try await playlists.set(on: command)
            try await outputs.set(on: command)
        }

        let isAlive = await connection.probe()

        guard !isAlive, self.connection === connection else {
            return
        }

        reinitialize()
    }

    /// Starts the task that owns the connection and listens for changes.
    private func start() {
        updateLoopTask = Task { [weak self] in
            await self?.updateLoop()
        }
    }

    /// The main update loop that maintains the MPD connection and state.
    ///
    /// Each pass connects, brings every manager up to date — changes that
    /// happened while disconnected are never reported by idle events — and
    /// then listens until the connection breaks, at which point it backs off
    /// and starts over.
    private func updateLoop() async {
        while !Task.isCancelled {
            guard let connection = await connect() else {
                return
            }

            try? await database.set(on: connection)
            try? await queue.set(on: connection)
            try? await playlists.set(on: connection)
            try? await status.set(on: connection)
            try? await outputs.set(on: connection)

            await listen(on: connection)

            // A cancelled loop must not tear down the connection: a successor
            // loop (see `reinitialize`) may already own a new one.
            guard !Task.isCancelled else {
                return
            }

            self.connection = nil
            await connection.disconnect()

            try? await Task.sleep(for: .seconds(2))
        }
    }

    /// Opens a connection to the MPD server, retrying every two seconds until
    /// it succeeds or the task is cancelled.
    ///
    /// - Returns: The connected manager, or `nil` if the task was cancelled.
    private func connect() async -> ConnectionManager<IdleMode>? {
        while !Task.isCancelled {
            let connection = ConnectionManager<IdleMode>()

            do {
                let states = try await connection.connect()

                guard !Task.isCancelled else {
                    await connection.disconnect()
                    return nil
                }

                self.connection = connection
                state.protocolVersion = await connection.version

                observeStates(states, of: connection)

                return connection
            } catch {
                await connection.disconnect()

                state.protocolVersion = nil
                state.error = error

                try? await Task.sleep(for: .seconds(2))
            }
        }

        return nil
    }

    /// Forwards connection-state events from `connection`'s stream into
    /// `StateManager`, for as long as it remains the current connection.
    ///
    /// The task needs no handle: `disconnect()` finishes the stream, so the
    /// loop always ends on its own. Ownership is rechecked on every event
    /// regardless, so that a replaced connection reporting its own teardown
    /// cannot overwrite the state of the one that succeeded it.
    private func observeStates(_ states: AsyncStream<ConnectionState>,
                               of connection: ConnectionManager<IdleMode>)
    {
        Task { [weak self] in
            for await connectionState in states {
                guard let self, self.connection === connection else {
                    return
                }

                state.connectionState = connectionState

                if connectionState == .ready {
                    state.error = nil
                }
            }
        }
    }

    /// Listens for idle events on `connection`, applying each batch, until
    /// the connection breaks or the task is cancelled.
    private func listen(on connection: ConnectionManager<IdleMode>) async {
        while !Task.isCancelled {
            do {
                let events = try await connection.idleForEvents(
                    mask: Self.subsystems,
                )

                try? await performUpdates(for: events, on: connection)
            } catch {
                return
            }
        }
    }

    /// Performs updates based on MPD idle events.
    ///
    /// A single idle response can report multiple changed subsystems; each
    /// one is mapped to the manager that mirrors it. The status is refreshed
    /// at most once, even when several subsystems that affect it changed.
    ///
    /// - Parameters:
    ///   - events: The changed subsystems reported by the idle command.
    ///   - connection: The connection to load over.
    /// - Throws: An error if any update operation fails.
    private func performUpdates(for events: [IdleEvent],
                                on connection: ConnectionManager<IdleMode>)
        async throws
    {
        if events.contains(.playlists) {
            try await playlists.set(on: connection)
        }

        if events.contains(.database) {
            try await database.set(on: connection)
        }

        if events.contains(.queue) {
            try await queue.set(on: connection)
        }

        if !Set(events).isDisjoint(with: [.queue, .player, .options, .mixer]) {
            try await status.set(on: connection)
        }

        if events.contains(.output) {
            try await outputs.set(on: connection)
        }
    }
}
