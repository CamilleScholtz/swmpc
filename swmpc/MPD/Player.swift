//
//  Player.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

@Observable final class Player {
    let status = Status()
    let queue = Queue()

    // TODO: Make these half private
    var currentSong: Song?
    // TODO: Add a setter for this
    var currentMedia: (any Mediable)?

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
        while await ConnectionManager.idle.connection?.state != .ready {
            do {
                try await ConnectionManager.idle.connect()
                print("INFO: Connected")

            } catch {
                try? await Task.sleep(for: .seconds(5))
            }
        }

        await performUpdates(for: "player")

        while !Task.isCancelled {
            if await ConnectionManager.idle.connection?.state != .ready {
                do {
                    try await ConnectionManager.idle.connect()
                } catch {
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }
            }

            let changes = try? await ConnectionManager.idle.idleForEvents(mask: ["playlist", "player", "options"])
            guard let changes else {
                continue
            }
            print(changes)

            await performUpdates(for: changes)
        }
    }

    @MainActor
    private func performUpdates(for change: String) async {
        switch change {
        case "playlist":
            await updatePlaylist()
        case "player":
            await updateOptions()
            await updatePlayer()
        case "options":
            await updateOptions()
        default:
            break
        }
    }

    @MainActor
    private func updatePlaylist() async {
        // playlists = try? await IdleManager.shared.getPlaylists()
    }

    @MainActor
    private func updatePlayer() async {
        if await currentSong.update(to: try? ConnectionManager.idle.getCurrentSong()) {
            AppDelegate.shared.setStatusItemTitle()
        }
    }

    @MainActor
    private func updateOptions() async {
        await status.set()
    }
}
