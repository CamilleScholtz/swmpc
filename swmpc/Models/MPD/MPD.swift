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
        while true {
            do {
                try await ConnectionManager.idle.connect()

                return
            } catch {
                // TODO: Set other stuff to nil as well?
                status.state = nil

                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @MainActor
    private func updateLoop() async {
        await connect()

        try? await performUpdates(for: .playlists)
        try? await performUpdates(for: .player)

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
            print("playlist")
            try await queue.setPlaylists()
        case .database, .queue:
            print("queue")
            try await queue.set()
            try await status.set()
        case .player:
            print("player")
            try await status.set()
        case .options:
            print("options")
            try await status.set()
        }
    }
}
