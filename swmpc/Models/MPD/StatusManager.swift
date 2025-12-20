//
//  StatusManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import AsyncAlgorithms
@preconcurrency import MediaPlayer
import MPDKit
import SwiftUI
import WidgetKit

/// Manages the MPD player status, including playback state, options, and
/// elapsed time tracking.
///
/// This class maintains the current player state and provides real-time elapsed
/// time tracking when playback is active. It automatically synchronizes with
/// the MPD server and updates platform-specific UI elements like the macOS
/// status bar.
@Observable final class StatusManager {
    /// The current player state (play, pause, stop).
    var state: PlayerState?

    /// Convenience property to check if the player is currently playing.
    var isPlaying: Bool {
        state == .play
    }

    /// Whether consume mode is enabled.
    private(set) var isConsume: Bool?

    /// Whether random/shuffle mode is enabled.
    private(set) var isRandom: Bool?

    /// Whether repeat mode is enabled.
    private(set) var isRepeat: Bool?

    /// The elapsed time of the current song in seconds.
    private(set) var elapsed: Double?

    /// The currently playing song.
    private(set) var song: Song?

    /// The current volume level (0-100).
    private(set) var volume: Int?

    /// Whether elapsed time tracking is currently active.
    @ObservationIgnored private(set) var trackElapsed = false {
        didSet {
            if trackElapsed {
                state == .play
                    ? startTrackingElapsedTask()
                    : stopTrackingElapsedTask()
            } else {
                stopTrackingElapsedTask()
            }
        }
    }

    /// The number of active tracking requests.
    @ObservationIgnored private var activeTrackingCount = 0 {
        didSet {
            if activeTrackingCount > 0, !trackElapsed {
                trackElapsed = true
            } else if activeTrackingCount == 0, trackElapsed {
                trackElapsed = false
            }
        }
    }

    /// The background task that updates elapsed time during playback.
    @ObservationIgnored private var trackingTask: Task<Void, Never>?

    /// The start time used for calculating elapsed time.
    @ObservationIgnored private var startTime: Date?

    /// Updates the status from the MPD server.
    ///
    /// This method fetches the current status from MPD and updates all relevant
    /// properties including playback state, options, elapsed time, and current
    /// song.  It also updates platform-specific UI elements like the macOS
    /// status bar.
    ///
    /// - Throws: An error if fetching the status fails.
    func set(idle: Bool = true) async throws {
        let data = try await idle
            ? ConnectionManager.idle.getStatusData()
            : ConnectionManager.command {
                try await $0.getStatusData()
            }

        let stateChanged = state.update(to: data.state)
        if stateChanged {
            #if os(macOS)
                let image = switch data.state {
                case .play:
                    "play"
                case .pause:
                    "pause"
                default:
                    "stop"
                }

                AppDelegate.shared?.setPopoverAnchorImage(changed: image)
            #endif

            if trackElapsed {
                state == .play
                    ? startTrackingElapsedTask()
                    : stopTrackingElapsedTask()
            }
        }

        if isConsume.update(to: data.isConsume ?? false) {
            #if os(macOS)
                AppDelegate.shared?.setPopoverAnchorImage(changed:
                    data.isConsume ?? false ? "consume" : "preserve")
            #endif
        }

        if isRandom.update(to: data.isRandom ?? false) {
            #if os(macOS)
                AppDelegate.shared?.setPopoverAnchorImage(changed:
                    data.isRandom ?? false ? "random" : "sequential")
            #endif
        }

        if isRepeat.update(to: data.isRepeat ?? false) {
            #if os(macOS)
                AppDelegate.shared?.setPopoverAnchorImage(changed:
                    data.isRepeat ?? false ? "repeat" : "single")
            #endif
        }

        _ = elapsed.update(to: data.elapsed ?? 0)
        if trackElapsed {
            if data.state == .play {
                stopTrackingElapsedTask()
                startTrackingElapsedTask()
            }
        }

        let songChanged = song.update(to: data.song)
        if songChanged {
            #if os(macOS)
                AppDelegate.shared?.setStatusItemTitle()
            #endif

            WidgetCenter.shared.reloadAllTimelines()
        }

        _ = volume.update(to: data.volume)

        if songChanged || stateChanged {
            await updateNowPlayingInfo()
        }
    }

    /// Starts tracking elapsed time for the current song.
    ///
    /// This method initiates real-time elapsed time tracking. Multiple
    /// omponents can request tracking, and tracking will continue until all
    /// requesters have called `stopTrackingElapsed()`.
    ///
    /// - Throws: An error if fetching the current status fails.
    func startTrackingElapsed() async throws {
        if !trackElapsed {
            let data = try await ConnectionManager.command {
                try await $0.getStatusData()
            }
            _ = elapsed.update(to: data.elapsed ?? 0)
        }

        activeTrackingCount += 1
    }

    /// Stops tracking elapsed time for the current song.
    ///
    /// This decrements the tracking count. When the count reaches zero, elapsed
    /// time tracking is completely stopped.
    func stopTrackingElapsed() {
        activeTrackingCount = max(0, activeTrackingCount - 1)
    }

    /// Starts the background task that updates elapsed time.
    ///
    /// This method creates a timer that updates the elapsed time every second
    /// while the player is in the play state.
    private func startTrackingElapsedTask() {
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
                guard !Task.isCancelled else {
                    return
                }

                if let startTime {
                    elapsed = Date().timeIntervalSince(startTime)
                }
            }
        }
    }

    /// Stops the background task that updates elapsed time.
    ///
    /// This method cancels the timer task and clears the tracking state.
    private func stopTrackingElapsedTask() {
        trackingTask?.cancel()

        trackingTask = nil
        startTime = nil
    }

    /// Updates the system Now Playing info center with current playback state.
    ///
    /// This method updates the Control Center and Lock Screen with track
    /// information, artwork, and playback state.
    private func updateNowPlayingInfo() async {
        guard let song else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album.title,
            MPMediaItemPropertyPlaybackDuration: song.duration,

            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: state == .play ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        if let artwork = await fetchNowPlayingArtwork(for: song) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().playbackState = state == .play ? .playing : .paused
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    /// Fetches artwork for the Now Playing info center.
    ///
    /// Uses `ArtworkManager` for caching the underlying artwork data.
    private func fetchNowPlayingArtwork(for song: Song) async -> MPMediaItemArtwork? {
        guard let artworkData = try? await song.artwork(),
              let image = artworkData.image
        else {
            return nil
        }

        return MPMediaItemArtwork(
            boundsSize: CGSize(width: 600, height: 600),
        ) { @Sendable _ in
            image
        }
    }
}
