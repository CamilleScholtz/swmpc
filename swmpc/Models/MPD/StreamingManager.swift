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
    enum State: Equatable {
        /// No stream is playing.
        case stopped
        /// Connecting to or buffering the stream.
        case loading
        /// Actively playing audio.
        case playing
        /// An error occurred.
        case error(String)
    }

    /// The current state of the streaming player.
    private(set) var state: State = .stopped

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var errorObserver: NSObjectProtocol?

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
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                state = .error("Audio session error: \(error.localizedDescription)")
                return
            }
        #endif

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        statusObservation = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.handleTimeControlStatusChange(player.timeControlStatus)
            }
        }

        errorObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem,
            queue: .main,
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            self?.state = .error(error?.localizedDescription ?? "Playback failed")
        }

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

        player?.pause()
        player = nil
        state = .stopped

        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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

    // MARK: - Private Methods

    private func handleTimeControlStatusChange(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .paused:
            // Only set to stopped if we intentionally stopped, not on stall
            break
        case .waitingToPlayAtSpecifiedRate:
            state = .loading
        case .playing:
            state = .playing
        @unknown default:
            break
        }
    }
}
