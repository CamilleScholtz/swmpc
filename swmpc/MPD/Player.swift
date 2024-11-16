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

    var current: Song?

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
        while !Task.isCancelled {
            if await !idleManager.isConnected {
                do {
                    try await idleManager.connect()
                } catch {
                    try! await Task.sleep(for: .seconds(5))
                    continue
                }
            }

            await status.set()
            if await current.update(to: idleManager.getSong()) {
                AppDelegate.shared.setStatusItemTitle()
            }

            let idleResult = await idleManager.runIdleMask(
                mask: mpd_idle(MPD_IDLE_PLAYER.rawValue | MPD_IDLE_OPTIONS.rawValue)
            )

            if idleResult == mpd_idle(0) {
                await idleManager.disconnect()
            }
        }
    }

    @MainActor
    func setSongs(for album: Album) async -> [Song] {
        try! await commandManager.getSongs(for: album)
    }

    @MainActor
    func setArtwork(for uri: URL) async {
        if let artwork = artworkCache.removeValue(forKey: uri) {
            artworkCache[uri] = artwork
            return
        }

        if artworkCache.count >= 64 {
            artworkCache.removeFirst()
        }

        let artwork = Artwork(uri: uri)
        artworkCache[uri] = artwork

        await artwork.set(using: commandManager)
    }

    @MainActor
    func getArtwork(for uri: URL?) -> Artwork? {
        guard let uri else {
            return nil
        }

        return artworkCache[uri]
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
