//
//  Player.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import libmpdclient
import OrderedCollections
import SwiftUI

@Observable final class Player {
    let status = Status()
    let queue = Queue()

    var currentSong: Song?
    var currentMedia: (any Mediable)?

    var playlists: [Playlist]?

    private(set) var artworkCache = OrderedDictionary<URL, Artwork>()

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
                try await IdleManager.shared.connect()
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
                    try await IdleManager.shared.connect()
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
            await IdleManager.shared.disconnect()
            return
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

    @MainActor
    func setArtwork(for media: any Artworkable) async {
        if let artwork = artworkCache.removeValue(forKey: media.uri) {
            artworkCache[media.uri] = artwork
            return
        }

        if artworkCache.count >= 64 {
            artworkCache.removeFirst()
        }

        let artwork = Artwork(uri: media.uri)
        artworkCache[media.uri] = artwork

        await artwork.set()
    }

    @MainActor
    func getArtwork(for media: (any Artworkable)?) -> Artwork? {
        guard let media else {
            return nil
        }

        return artworkCache[media.uri]
    }
}
