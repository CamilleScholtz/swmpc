//
//  StatusManager+MediaPlayer.swift
//  swmpc
//
//  Created by Camille Scholtz on 20/12/2025.
//

@preconcurrency import MediaPlayer
import MPDKit

extension StatusManager {
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

        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let positionEvent = event as?
                MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }

            Task(priority: .userInitiated) {
                try? await ConnectionManager.command {
                    try await $0.seek(positionEvent.positionTime)
                }
            }

            return .success
        }

        commandCenter.stopCommand.addTarget { _ in
            Task(priority: .userInitiated) {
                try? await ConnectionManager.command {
                    try await $0.stop()
                }
            }

            return .success
        }

        commandCenter.changeRepeatModeCommand.addTarget { event in
            guard let repeatEvent = event as? MPChangeRepeatModeCommandEvent
            else {
                return .commandFailed
            }

            Task(priority: .userInitiated) {
                try? await ConnectionManager.command {
                    try await $0.repeat(repeatEvent.repeatType != .off)
                }
            }

            return .success
        }

        commandCenter.changeShuffleModeCommand.addTarget { event in
            guard let shuffleEvent = event as? MPChangeShuffleModeCommandEvent
            else {
                return .commandFailed
            }

            Task(priority: .userInitiated) {
                try? await ConnectionManager.command {
                    try await $0.random(shuffleEvent.shuffleType != .off)
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
        commandCenter.changePlaybackRateCommand.isEnabled = false
    }

    /// Updates song metadata and artwork in the Now Playing info center.
    ///
    /// Call this when the song changes. For state-only changes (play/pause),
    /// use `updateNowPlayingPlaybackState()` instead.
    func updateNowPlayingSong() async {
        guard let song else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album.title,
            MPMediaItemPropertyAlbumArtist: song.album.artist.name,
            MPMediaItemPropertyPlaybackDuration: song.duration,
            MPMediaItemPropertyAlbumTrackNumber: song.track,
            MPMediaItemPropertyDiscNumber: song.disc,

            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed ?? 0,
            MPNowPlayingInfoPropertyPlaybackRate: state == .play ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio
                .rawValue,
            MPNowPlayingInfoPropertyExternalContentIdentifier: song.file,
        ]

        if let genre = song.genre {
            nowPlayingInfo[MPMediaItemPropertyGenre] = genre
        }
        if let composer = song.composer {
            nowPlayingInfo[MPMediaItemPropertyComposer] = composer
        }

        nowPlayingInfo[MPMediaItemPropertyArtwork] = await
            fetchNowPlayingArtwork(for: song)

        MPNowPlayingInfoCenter.default().playbackState = state == .play ?
            .playing : .paused
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    /// Updates only the playback state in the Now Playing info center.
    ///
    /// This is a lightweight update for play/pause state changes that doesn't
    /// re-fetch artwork. Call `updateNowPlayingSong()` when the song changes.
    func updateNowPlayingPlaybackState() {
        guard song != nil else {
            return
        }

        MPNowPlayingInfoCenter.default().playbackState = state == .play ?
            .playing : .paused

        if var nowPlayingInfo = MPNowPlayingInfoCenter.default()
            .nowPlayingInfo
        {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
                elapsed ?? 0
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] =
                state == .play ? 1.0 : 0.0

            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }

    /// Updates the command center's repeat and shuffle mode states.
    ///
    /// Call this after status updates to keep Control Center in sync with MPD.
    func updateRemoteCommandModes() {
        MPRemoteCommandCenter.shared().changeRepeatModeCommand
            .currentRepeatType = isRepeat == true ? .all : .off
        MPRemoteCommandCenter.shared().changeShuffleModeCommand
            .currentShuffleType = isRandom == true ? .items : .off
    }

    /// Fetches artwork for the Now Playing info center.
    ///
    /// Uses `ArtworkManager` for caching the underlying artwork data.
    private func fetchNowPlayingArtwork(for song: Song) async ->
        MPMediaItemArtwork?
    {
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
