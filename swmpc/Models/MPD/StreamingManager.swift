//
//  StreamingManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 15/12/2025.
//

import AVFoundation
import MPDKit
import Observation

/// Manages audio streaming from MPD's httpd output using AVPlayer.
@Observable final class StreamingManager {
    /// The current state of the streaming player.
    private(set) var state: StreamState = .stopped

    /// The AVPlayer instance used for streaming.
    @ObservationIgnored private var player: AVPlayer?

    /// Observers for player status and errors.
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?

    /// Observer for playback errors.
    @ObservationIgnored private var errorObserver: NSObjectProtocol?

    #if os(iOS)
        /// Observer for audio session interruptions (phone calls, Siri, other
        /// apps claiming the session).
        @ObservationIgnored private var interruptionObserver: NSObjectProtocol?

        /// Observer for audio route changes (e.g. headphones being
        /// disconnected).
        @ObservationIgnored private var routeChangeObserver: NSObjectProtocol?
    #endif

    /// Two-way access to the streaming state, usable as a key path binding
    /// (`$streaming[isStreamingFrom: server]`).
    subscript(isStreamingFrom server: Server) -> Bool {
        get {
            state != .stopped
        }
        set {
            if newValue {
                startStreaming(from: server)
            } else {
                stopStreaming()
            }
        }
    }

    /// Starts streaming audio from the specified server.
    ///
    /// - Parameter server: The server configuration to stream from.
    func startStreaming(from server: Server) {
        guard let url = server.streamURL else {
            state = .error("No stream URL configured")
            return
        }

        stopStreaming()
        state = .loading

        #if os(iOS)
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode:
                    .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                state = .error(
                    "Audio session error: \(error.localizedDescription)",
                )

                return
            }
        #endif

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        statusObservation = player?.observe(\.timeControlStatus, options: [
            .new,
        ]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatusChange(player.timeControlStatus)
            }
        }

        errorObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: playerItem,
            queue: .main,
        ) { [weak self] notification in
            let error = notification.userInfo?[
                AVPlayerItemFailedToPlayToEndTimeErrorKey,
            ] as? Error

            Task { @MainActor [weak self] in
                self?.state = .error(error?.localizedDescription ?? "Playback failed")
            }
        }

        #if os(iOS)
            interruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main,
            ) { [weak self] notification in
                guard let typeValue = notification.userInfo?[
                    AVAudioSessionInterruptionTypeKey,
                ] as? UInt,
                    let type = AVAudioSession.InterruptionType(rawValue:
                        typeValue)
                else {
                    return
                }

                let shouldResume = (notification.userInfo?[
                    AVAudioSessionInterruptionOptionKey,
                ] as? UInt).map {
                    AVAudioSession.InterruptionOptions(rawValue: $0)
                        .contains(.shouldResume)
                } ?? false

                Task { @MainActor [weak self] in
                    self?.handleInterruption(type: type, shouldResume:
                        shouldResume)
                }
            }

            routeChangeObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main,
            ) { [weak self] notification in
                guard let reasonValue = notification.userInfo?[
                    AVAudioSessionRouteChangeReasonKey,
                ] as? UInt,
                    let reason = AVAudioSession.RouteChangeReason(rawValue:
                        reasonValue),
                    reason == .oldDeviceUnavailable
                else {
                    return
                }

                // The active output device disappeared (e.g. headphones were
                // disconnected); stop rather than continue on the speaker.
                Task { @MainActor [weak self] in
                    self?.stopStreaming()
                }
            }
        #endif

        player?.play()
    }

    /// Stops the current audio stream.
    func stopStreaming() {
        statusObservation?.invalidate()
        statusObservation = nil

        if let errorObserver {
            NotificationCenter.default.removeObserver(errorObserver)
        }
        errorObserver = nil

        #if os(iOS)
            if let interruptionObserver {
                NotificationCenter.default.removeObserver(interruptionObserver)
            }
            interruptionObserver = nil

            if let routeChangeObserver {
                NotificationCenter.default.removeObserver(routeChangeObserver)
            }
            routeChangeObserver = nil
        #endif

        player?.pause()
        player = nil
        state = .stopped

        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options:
                .notifyOthersOnDeactivation)
        #endif
    }

    /// Toggles the streaming state.
    ///
    /// - Parameter server: The server configuration to stream from when starting.
    func toggleStreaming(from server: Server) {
        if state != .stopped {
            stopStreaming()
        } else {
            startStreaming(from: server)
        }
    }

    #if os(iOS)
        /// Handles audio session interruptions.
        ///
        /// The player is paused for the duration of the interruption. When the
        /// interruption ends, playback resumes only if the system indicates it
        /// should (e.g. after a phone call); otherwise the stream is stopped,
        /// since another app has taken over audio.
        private func handleInterruption(type: AVAudioSession.InterruptionType,
                                        shouldResume: Bool)
        {
            switch type {
            case .began:
                player?.pause()
            case .ended:
                if shouldResume {
                    player?.play()
                } else {
                    stopStreaming()
                }
            @unknown default:
                break
            }
        }
    #endif

    private func handleTimeControlStatusChange(_ status:
        AVPlayer.TimeControlStatus)
    {
        switch status {
        case .waitingToPlayAtSpecifiedRate:
            state = .loading
        case .playing:
            state = .playing
        case .paused:
            break
        @unknown default:
            break
        }
    }
}
