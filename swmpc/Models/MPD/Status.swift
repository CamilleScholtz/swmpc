//
//  Status.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import AsyncAlgorithms
import SwiftUI

@Observable
final class Status {
    var state: PlayerState?
    var isPlaying: Bool {
        state == .play
    }

    var isRandom: Bool?
    var isRepeat: Bool?
    var elapsed: Double?

    var song: Song?
    // TODO: I currently set this in SidebarView, I'd rather want to do it here,
    // however, accessing the navigator from here feels wrong.
    var media: (any Mediable)?
    var playlist: Playlist?

    @ObservationIgnored @MainActor private(set) var trackElapsed = false {
        didSet {
            if trackElapsed {
                state == .play ? startTrackingElapsed() : stopTrackingElapsed()
            } else {
                stopTrackingElapsed()
            }
        }
    }

    @ObservationIgnored @MainActor private var activeTrackingCount = 0 {
        didSet {
            if activeTrackingCount > 0, !trackElapsed {
                trackElapsed = true
            } else if activeTrackingCount == 0, trackElapsed {
                trackElapsed = false
            }
        }
    }

    private var trackingTask: Task<Void, Never>?
    private var startTime: Date?

    @MainActor
    func startTracking() {
        activeTrackingCount += 1
    }

    @MainActor
    func stopTracking() {
        activeTrackingCount = max(0, activeTrackingCount - 1)
    }

    @MainActor
    func set() async throws {
        let data = try await ConnectionManager.idle.getStatusData()

        if state.update(to: data.state) {
            #if os(macOS)
                let image = switch data.state {
                case .play:
                    "play"
                case .pause:
                    "pause"
                default:
                    "stop"
                }

                AppDelegate.shared.setPopoverAnchorImage(changed: image)
            #endif

            if trackElapsed {
                state == .play ? startTrackingElapsed() : stopTrackingElapsed()
            }
        }

        if isRandom.update(to: data.isRandom ?? false) {
            #if os(macOS)
                AppDelegate.shared.setPopoverAnchorImage(changed:
                    data.isRandom ?? false ? "random" : "sequential")
            #endif
        }

        if isRepeat.update(to: data.isRepeat ?? false) {
            #if os(macOS)
                AppDelegate.shared.setPopoverAnchorImage(changed:
                    data.isRepeat ?? false ? "repeat" : "single")
            #endif
        }

        _ = elapsed.update(to: data.elapsed ?? 0)
        if trackElapsed {
            if data.state == .play {
                stopTrackingElapsed()
                startTrackingElapsed()
            }
        }

        if song.update(to: data.song) {
            #if os(macOS)
                AppDelegate.shared.setStatusItemTitle()
            #endif
        }

        _ = playlist.update(to: data.playlist)
    }

    @MainActor
    private func startTrackingElapsed() {
        if let trackingTask, !trackingTask.isCancelled {
            stopTrackingElapsed()
        }

        startTime = Date() - (elapsed ?? 0)

        trackingTask = Task { [weak self] in
            guard let self else {
                return
            }

            let timer = AsyncTimerSequence(interval: .seconds(1), tolerance:
                .seconds(0.1), clock: .suspending)
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
