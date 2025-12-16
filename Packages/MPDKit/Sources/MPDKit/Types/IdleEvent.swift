//
//  IdleEvent.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Represents the different subsystems that MPD monitors for changes.
///
/// These events are used with MPD's idle command to receive notifications.
public enum IdleEvent: String, Sendable {
    /// The music database has been updated.
    case database
    /// Stored playlists have been modified.
    case playlists = "stored_playlist"
    /// The current queue has changed.
    case queue = "playlist"
    /// Player options (repeat, random, etc.) have changed.
    case options
    /// The player state (play, pause, stop) or current song has changed.
    case player
    /// The mixer volume has changed.
    case mixer
    /// An audio output has been added, removed, or modified.
    case output
}
