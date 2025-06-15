//
//  MPD.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

@Observable final class MPD {
    let status = Status()
    let database = Database()
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

        @AppStorage(Setting.simpleMode) var simpleMode = false
        if simpleMode {
            try? await ConnectionManager.command().loadPlaylist(nil)
        }

        try? await database.set(using: .album, idle: true)
        try? await status.set()
        try? await database.setPlaylists()
        await queue.load()

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
            try await database.setPlaylists()
        case .database:
            try await database.set()
        case .queue:
            await queue.reload()
            NotificationCenter.default.post(name: .queueChangedNotification, object: nil)
        case .player:
            try await status.set()
        case .options:
            try await status.set()
        }
    }
}
