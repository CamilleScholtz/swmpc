//
//  StatusManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import AsyncAlgorithms
import SwiftUI

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

    /// Whether random/shuffle mode is enabled.
    var isRandom: Bool?

    /// Whether repeat mode is enabled.
    var isRepeat: Bool?

    /// The elapsed time of the current song in seconds.
    var elapsed: Double?

    /// The currently playing song.
    var song: Song?

    /// The currently loaded playlist, if any.
    var playlist: Playlist?

    /// The current volume level (0-100).
    var volume: Int?

    /// Gets the media ID for the current song based on the specified media type.
    ///
    /// This method finds the appropriate media item (album, artist, or song) that
    /// corresponds to the currently playing song.
    ///
    /// - Parameters:
    ///   - type: The type of media to search for.
    ///   - media: The collection of media items to search within.
    /// - Returns: The ID of the found media item, or nil if not found.
    func getMediaID(for type: MediaType, in media: [any Mediable]) -> String? {
        guard let currentSong = song else { return nil }

        switch type {
        case .album:
            // Find the album that contains the current song
            return (media as? [Album])?.first(where: { currentSong.isIn($0) })?.id
        case .artist:
            // Find the artist that performed the current song
            return (media as? [Artist])?.first(where: { currentSong.isBy($0) })?.id
        case .song:
            // For songs, just use the song's ID directly
            return currentSong.id
        case .playlist:
            // Playlists don't apply here
            return nil
        }
    }

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
    private var trackingTask: Task<Void, Never>?

    /// The start time used for calculating elapsed time.
    private var startTime: Date?

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
            : ConnectionManager.command().getStatusData()

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
                state == .play
                    ? startTrackingElapsedTask()
                    : stopTrackingElapsedTask()
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
                stopTrackingElapsedTask()
                startTrackingElapsedTask()
            }
        }

        if song.update(to: data.song) {
            #if os(macOS)
                AppDelegate.shared.setStatusItemTitle()
            #endif
        }

        _ = playlist.update(to: data.playlist)
        _ = volume.update(to: data.volume)
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
            let data = try await ConnectionManager.command().getStatusData()
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
}
