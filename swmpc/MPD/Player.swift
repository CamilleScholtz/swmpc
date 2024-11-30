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
    let status: Status
    let queue: Queue

    var currentSong: Song?
    var currentMedia: (any Mediable)?

    var playlists: [Playlist]?

    private(set) var artworkCache = OrderedDictionary<URL, Artwork>()

    @ObservationIgnored let idleManager = ConnectionManager(idle: true)
    @ObservationIgnored let commandManager = ConnectionManager()

    private var updateLoopTask: Task<Void, Never>?

    @MainActor
    init() {
        status = Status(idleManager: idleManager, commandManager: commandManager)
        queue = Queue(idleManager: idleManager, commandManager: commandManager)

        updateLoopTask = Task { [weak self] in
            await self?.updateLoop()
        }
    }

    deinit {
        updateLoopTask?.cancel()
    }

    @MainActor
    private func updateLoop() async {
        while await !idleManager.isConnected {
            do {
                try await idleManager.connect()
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
            if await !idleManager.isConnected {
                do {
                    try await idleManager.connect()
                } catch {
                    try? await Task.sleep(for: .seconds(5))
                    continue
                }
            }

            let idleResult = await idleManager.runIdleMask(
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
            await idleManager.disconnect()
            return
        }
        
        if (idleResult.rawValue & MPD_IDLE_PLAYER.rawValue) != 0 ||
            (idleResult.rawValue & MPD_IDLE_OPTIONS.rawValue) != 0
        {
            await status.set()
            if await currentSong.update(to: try? idleManager.getCurrentSong()) {
                AppDelegate.shared.setStatusItemTitle()
            }
        }

        if (idleResult.rawValue & MPD_IDLE_STORED_PLAYLIST.rawValue) != 0 {
            await setPlaylists()
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

        await artwork.set(using: commandManager)
    }

    @MainActor
    func getArtwork(for media: (any Artworkable)?) -> Artwork? {
        guard let media else {
            return nil
        }

        return artworkCache[media.uri]
    }
    
    @MainActor
    func setPlaylists() async {
        playlists = try? await commandManager.getPlaylists()
    }

    @MainActor
    func createPlaylist(_ name: String) async {
        try? await commandManager.createPlaylist(name)
    }

    @MainActor
    func play(_ media: any Mediable) async {
        await commandManager.runPlay(media)
    }

    @MainActor
    func pause(_ value: Bool) async {
        await commandManager.runPause(value)
    }

    @MainActor
    func previous() async {
        await commandManager.runPrevious()
    }

    @MainActor
    func next() async {
        await commandManager.runNext()
    }

    @MainActor
    func seek(_ value: Double) async {
        await commandManager.runSeekCurrent(value)
    }

    @MainActor
    func setRandom(_ value: Bool) async {
        await commandManager.runRandom(value)
    }

    @MainActor
    func setRepeat(_ value: Bool) async {
        await commandManager.runRepeat(value)
    }
}
