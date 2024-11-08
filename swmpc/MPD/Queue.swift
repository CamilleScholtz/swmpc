//
//  Queue.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import libmpdclient
import SwiftUI

@Observable final class Queue {
    private let idleManager: ConnectionManager
    private let commandManager: ConnectionManager

    var albums: [Album] = []

    @MainActor
    init(idleManager: ConnectionManager, commandManager: ConnectionManager) {
        self.idleManager = idleManager
        self.commandManager = commandManager

        Task {
            await set()
        }
    }

    @MainActor
    func set() async {
        albums = await idleManager.getQueue(tag: MPD_TAG_ALBUM)
    }

    @MainActor
    func setArtwork(_ id: String) async {
        guard let index = albums.firstIndex(where: { $0.id == id }) else {
            return
        }

        let artwork = await commandManager.getArtwork(location: id)
        guard let artwork else {
            return
        }

        var album = albums[index]
        album.artwork = artwork

        albums[index] = album
    }
}
