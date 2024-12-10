//
//  Status.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import AsyncAlgorithms
import SwiftUI

@Observable final class Status {
    var isPlaying: Bool?
    var isRandom: Bool?
    var isRepeat: Bool?
    var elapsed: Double?

    @ObservationIgnored @MainActor var trackElapsed: Bool = false {
        didSet {
            if trackElapsed {
                startTrackingElapsed()
            } else {
                stopTrackingElapsed()
            }
        }
    }

    private var trackingTask: Task<Void, Never>?
    private var startTime: Date?

    @MainActor
    func set() async {
        guard let data = try? await ConnectionManager.idle.getStatusData() else {
            return
        }

        if trackElapsed {
            if elapsed.update(to: data.elapsed ?? 0), data.isPlaying ?? false {
                stopTrackingElapsed()
                startTrackingElapsed()
            }
        }

        if isPlaying.update(to: data.isPlaying ?? false) {
            AppDelegate.shared.setPopoverAnchorImage(changed: data.isPlaying ?? false ? "play" : "pause")

            if trackElapsed {
                data.isPlaying ?? false ? startTrackingElapsed() : stopTrackingElapsed()
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
    private func startTrackingElapsed() {
        if let trackingTask, !trackingTask.isCancelled {
            return
        }

        startTime = Date() - (elapsed ?? 0)

        trackingTask = Task { [weak self] in
            guard let self else {
                return
            }

            let timer = AsyncTimerSequence(interval: .seconds(1), tolerance: .seconds(0.1), clock: .suspending)
            for await _ in timer {
                guard trackElapsed else {
                    break
                }

                if let startTime {
                    elapsed = Date().timeIntervalSince(startTime)
                }
            }
        }
    }

    @MainActor
    private func stopTrackingElapsed() {
        trackingTask?.cancel()

        trackingTask = nil
        startTime = nil
    }
}
