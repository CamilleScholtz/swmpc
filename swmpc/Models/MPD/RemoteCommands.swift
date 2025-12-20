//
//  RemoteCommands.swift
//  swmpc
//
//  Created by Camille Scholtz on 20/12/2024.
//

@preconcurrency import MediaPlayer
import MPDKit

extension MPD {
    /// Configures handlers for media key commands.
    func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { _ in
            Task(priority: .userInitiated) {
                try? await ConnectionManager.command {
                    try await $0.pause(false)
                }
            }

            return .success
        }

        commandCenter.pauseCommand.addTarget { _ in
            Task(priority: .userInitiated) {
                try? await ConnectionManager.command {
                    try await $0.pause(true)
                }
            }

            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else {
                return .commandFailed
            }

            let isPlaying = status.isPlaying

            Task(priority: .userInitiated) {
                try? await ConnectionManager.command {
                    try await $0.pause(isPlaying)
                }
            }

            return .success
        }

        commandCenter.nextTrackCommand.addTarget { _ in
            Task(priority: .userInitiated) {
                try? await ConnectionManager.command {
                    try await $0.next()
                }
            }

            return .success
        }

        commandCenter.previousTrackCommand.addTarget { _ in
            Task(priority: .userInitiated) {
                try? await ConnectionManager.command {
                    try await $0.previous()
                }
            }

            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { event
            in
            guard let positionEvent = event as?
                MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }

            let position = positionEvent.positionTime

            Task(priority: .userInitiated) {
                try? await ConnectionManager.command {
                    try await $0.seek(position)
                }
            }

            return .success
        }

        commandCenter.seekForwardCommand.isEnabled = false
        commandCenter.seekBackwardCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.ratingCommand.isEnabled = false
        commandCenter.likeCommand.isEnabled = false
        commandCenter.dislikeCommand.isEnabled = false
        commandCenter.bookmarkCommand.isEnabled = false
    }
}
