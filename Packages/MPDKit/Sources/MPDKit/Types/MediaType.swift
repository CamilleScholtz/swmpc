//
//  MediaType.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Represents the different types of media that can be managed by MPD.
public enum MediaType: Sendable {
    /// An album containing multiple songs.
    case album
    /// An artist who has created music.
    case artist
    /// An individual song or track.
    case song
    /// A user-created playlist of songs.
    case playlist
}
