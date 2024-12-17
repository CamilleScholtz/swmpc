//
//  Status.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import AsyncAlgorithms
import SwiftUI

@Observable final class Status {
    var state: PlayerState?
    var isPlaying: Bool? {
        state == .play
    }

    var isRandom: Bool?
    var isRepeat: Bool?
    var elapsed: Double?

    var song: Song?
    // TODO: Create setter for this
    var media: (any Mediable)?
    var playlist: Playlist?

    private var trackingTask: Task<Void, Never>?
    private var startTime: Date?

    @ObservationIgnored @MainActor var trackElapsed: Bool = false {
        didSet {
            if trackElapsed {
                startTrackingElapsed()
            } else {
                stopTrackingElapsed()
            }
        }
    }

    @MainActor
    func set() async {
        guard let data = try? await ConnectionManager.shared.getStatusData() else {
            return
        }

        if trackElapsed {
            if elapsed.update(to: data.elapsed ?? 0), data.state == .play {
                stopTrackingElapsed()
                startTrackingElapsed()
            }
        }

        if state.update(to: data.state) {
            let image = switch data.state {
            case .play:
                "play"
            case .pause:
                "pause"
            default:
                "stop"
            }

            AppDelegate.shared.setPopoverAnchorImage(changed: image)

            if trackElapsed {
                data.state == .play ? startTrackingElapsed() : stopTrackingElapsed()
            }
        }

        if isRandom.update(to: data.isRandom ?? false) {
            AppDelegate.shared.setPopoverAnchorImage(changed: data.isRandom ?? false ? "random" : "sequential")
        }

        if isRepeat.update(to: data.isRepeat ?? false) {
            AppDelegate.shared.setPopoverAnchorImage(changed: data.isRepeat ?? false ? "repeat" : "single")
        }

        if song.update(to: data.song) {
            AppDelegate.shared.setStatusItemTitle()
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
