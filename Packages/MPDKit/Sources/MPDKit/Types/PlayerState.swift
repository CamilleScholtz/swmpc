//
//  PlayerState.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Represents the current playback state of the MPD player.
public enum PlayerState: Sendable {
    /// The player is currently playing music.
    case play
    /// The player is paused.
    case pause
    /// The player is stopped.
    case stop
}
