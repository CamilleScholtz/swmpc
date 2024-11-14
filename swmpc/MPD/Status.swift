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
    
    @ObservationIgnored @MainActor var trackElapsed: Bool = false {
        didSet {
            if trackElapsed {
                Task {
                    await self.startTrackingElapsed()
                }
            } else {
                stopTrackingElapsed()
            }
        }
    }

    private var trackingTask: Task<Void, Never>?
    private var startTime: Date?

    init(idleManager: ConnectionManager, commandManager: ConnectionManager) {
        self.idleManager = idleManager
        self.commandManager = commandManager
    }

    @MainActor
    func set() async {
        let data = await idleManager.getStatusData()

        if trackElapsed {
            if elapsed.update(to: data.elapsed ?? 0), data.isPlaying ?? false {
                stopTrackingElapsed()
                await startTrackingElapsed()
            }
        }
        
        if isPlaying.update(to: data.isPlaying ?? false) {
            AppDelegate.shared.setPopoverAnchorImage(changed: data.isPlaying ?? false ? "play" : "pause")

            if trackElapsed {
                data.isPlaying ?? false ? await startTrackingElapsed() : stopTrackingElapsed()
            }
        }
        if isRandom.update(to: data.isRandom ?? false) {
            AppDelegate.shared.setPopoverAnchorImage(changed: data.isRandom ?? false ? "random" : "sequential")
        }
        if isRepeat.update(to: data.isRepeat ?? false) {
            AppDelegate.shared.setPopoverAnchorImage(changed: data.isRepeat ?? false ? "repeat" : "single")
        }
    }

    @MainActor
    private func startTrackingElapsed() async {
        if let trackingTask, !trackingTask.isCancelled {
            return
        }
        
        startTime = Date() - (elapsed ?? 0)

        trackingTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled && trackElapsed {
                try? await Task.sleep(for: .seconds(0.75), tolerance: .seconds(0.25))
                
                let currentTime = Date()
                if let startTime = self.startTime {
                    self.elapsed = currentTime.timeIntervalSince(startTime)
                }
            }
        }
    }

    private func stopTrackingElapsed() {
        trackingTask?.cancel()
        
        trackingTask = nil
        startTime = nil
    }
}
