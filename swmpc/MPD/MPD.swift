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

    var playlists: [Playlist]?

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

        await performUpdates(for: "player")

        while !Task.isCancelled {
            if await (try? ConnectionManager.shared.ensureConnectionReady()) == nil {
                do {
                    try await ConnectionManager.shared.connect()
                } catch {
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }
            }

            let changes = try? await ConnectionManager.shared.idleForEvents(mask: ["playlist", "player", "options"])
            guard let changes else {
                continue
            }

            await performUpdates(for: changes)
        }
    }

    @MainActor
    private func performUpdates(for change: String) async {
        switch change {
        case "playlist":
            print("TODO")
        // playlists = try? await IdleManager.shared.getPlaylists()
        case "player":
            await status.set()
        case "options":
            await status.set()
        default:
            break
        }
    }
}
