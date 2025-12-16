//
//  ArtworkGetter.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Specifies the method for retrieving artwork from MPD.
public enum ArtworkGetter: String, Codable, Sendable {
    /// Retrieve artwork from the music library folder structure.
    case library = "albumart"
    /// Retrieve artwork embedded in the audio file.
    case metadata = "readpicture"
}
