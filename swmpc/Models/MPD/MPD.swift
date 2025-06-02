//
//  MPD.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

@Observable final class MPD {
    let status = Status()
    let queue = Queue()

    var error: Error?

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

    @MainActor
    private func updateLoop() async {
        await connect()

        @AppStorage(Setting.simpleMode) var loadEntireDatabase = false

        if loadEntireDatabase {
            // Load entire database into queue on startup (current behavior)
            do {
                try await ConnectionManager.command().loadPlaylist(nil)
            } catch {
                // If loading fails, continue anyway
            }
        }

        try? await queue.set(using: .album, idle: true)
        try? await status.set()
        try? await queue.setPlaylists()

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

    @MainActor
    private func performUpdates(for change: IdleEvent) async throws {
        switch change {
        case .playlists:
            try await queue.setPlaylists()
        case .database:
            @AppStorage(Setting.simpleMode) var loadEntireDatabase = false
            if !loadEntireDatabase {
                // In database mode, database changes don't affect our view
                // unless we're viewing the queue
                if status.playlist == nil {
                    try await queue.set(force: true)
                }
            } else {
                // In load entire database mode, reload everything
                try await queue.set()
            }
            try await status.set()
        case .queue:
            @AppStorage(Setting.simpleMode) var loadEntireDatabase = false
            if !loadEntireDatabase {
                // Queue changed, notify queue view
                NotificationCenter.default.post(name: .queueChangedNotification, object: nil)
            } else {
                // In load entire database mode, queue is our view
                try await queue.set()
            }
            try await status.set()
        case .player:
            try await status.set()
        case .options:
            try await status.set()
        }
    }
}
