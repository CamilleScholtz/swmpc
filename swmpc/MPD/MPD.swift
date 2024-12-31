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

    let categories: [Category] = [
        .init(id: MediaType.album, label: "Albums", image: "square.stack"),
        .init(id: MediaType.artist, label: "Artists", image: "music.microphone"),
        .init(id: MediaType.song, label: "Songs", image: "music.note"),
        .init(id: MediaType.playlist, label: "Playlists", image: "music.note.list", list: false),
    ]

    var label: String {
        categories.first { $0.id == queue.type }?.label ?? ""
    }

    var image: String {
        categories.first { $0.id == queue.type }?.image ?? ""
    }

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
    private func updateLoop() async {
        while await (try? ConnectionManager.shared.ensureConnectionReady()) == nil {
            do {
                try await ConnectionManager.shared.connect()
            } catch {
                try? await Task.sleep(for: .seconds(5))
            }
        }

        try? await performUpdates(for: .playlists)
        try? await performUpdates(for: .player)

        while !Task.isCancelled {
            if await (try? ConnectionManager.shared.ensureConnectionReady()) == nil {
                do {
                    try await ConnectionManager.shared.connect()
                } catch {
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }
            }

            let changes = try? await ConnectionManager.shared.idleForEvents(mask: [
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
        case .queue:
            print("queue")
            try await queue.set()
        case .player:
            try await status.set()
        case .options:
            try await status.set()
        }
    }
}
