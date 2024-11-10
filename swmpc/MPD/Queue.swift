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
    var artists: [Artist] = []
    var songs: [Song] = []

    @MainActor
    init(idleManager: ConnectionManager, commandManager: ConnectionManager) {
        self.idleManager = idleManager
        self.commandManager = commandManager
        
        Task {
            albums = await idleManager.getQueue(using: .album) as! [Album]
        }
    }

    @MainActor
    func set(using type: MediaType) async {

    }
}
