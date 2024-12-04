//
//  Player.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import libmpdclient
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
        while await !IdleManager.shared.isConnected {
            do {
                try await IdleManager.shared.connect(isolation: IdleManager.shared, idle: true)
            } catch {
                try? await Task.sleep(for: .seconds(5))
            }
        }

        await performUpdates(for: mpd_idle(
            MPD_IDLE_PLAYER.rawValue |
                MPD_IDLE_OPTIONS.rawValue |
                MPD_IDLE_STORED_PLAYLIST.rawValue
        ))

        while !Task.isCancelled {
            if await !IdleManager.shared.isConnected {
                do {
                    try await IdleManager.shared.connect(isolation: IdleManager.shared, idle: true)
                } catch {
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }
            }

            let idleResult = await IdleManager.shared.runIdleMask(
                mask: mpd_idle(
                    MPD_IDLE_PLAYER.rawValue |
                        MPD_IDLE_OPTIONS.rawValue |
                        MPD_IDLE_STORED_PLAYLIST.rawValue
                )
            )

            await performUpdates(for: idleResult)
        }
    }

    @MainActor
    private func performUpdates(for idleResult: mpd_idle) async {
        guard idleResult != mpd_idle(0) else {
            return await IdleManager.shared.disconnect(isolation: IdleManager.shared)
        }

        if (idleResult.rawValue & MPD_IDLE_PLAYER.rawValue) != 0 ||
            (idleResult.rawValue & MPD_IDLE_OPTIONS.rawValue) != 0
        {
            await status.set()
            if await currentSong.update(to: try? IdleManager.shared.getCurrentSong()) {
                AppDelegate.shared.setStatusItemTitle()
            }
        }

        if (idleResult.rawValue & MPD_IDLE_STORED_PLAYLIST.rawValue) != 0 {
            playlists = try? await IdleManager.shared.getPlaylists()
        }
    }
}
