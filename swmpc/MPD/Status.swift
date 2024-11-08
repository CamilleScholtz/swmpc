//
//  Status.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

@Observable final class Status {
    private let idleManager: ConnectionManager
    private let commandManager: ConnectionManager

    var isPlaying: Bool?
    var isRandom: Bool?
    var isRepeat: Bool?
    var elapsed: Double?

    @ObservationIgnored var trackingTask: Task<Void, Never>?

    init(idleManager: ConnectionManager, commandManager: ConnectionManager) {
        self.idleManager = idleManager
        self.commandManager = commandManager
    }

    @MainActor
    func set() async {
        let data = await idleManager.getStatusData()

        if isPlaying.update(to: data.isPlaying ?? false) {
            AppDelegate.shared.setPopoverAnchorImage(changed: data.isPlaying ?? false ? "play" : "pause")
        }
        if isRandom.update(to: data.isRandom ?? false) {
            AppDelegate.shared.setPopoverAnchorImage(changed: data.isRandom ?? false ? "random" : "sequential")
        }
        if isRepeat.update(to: data.isRepeat ?? false) {
            AppDelegate.shared.setPopoverAnchorImage(changed: data.isRepeat ?? false ? "repeat" : "single")
        }
        _ = elapsed.update(to: data.elapsed ?? 0)
    }

    @MainActor
    func trackElapsed() async {
        trackingTask?.cancel()

        trackingTask = Task { [weak self] in
            while !Task.isCancelled {
                if let elapsedData = await self?.commandManager.getElapsedData() {
                    self?.elapsed = elapsedData
                }

                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
}
