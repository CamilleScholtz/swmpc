//
//  ArtworkGetter.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// An MPD command that returns artwork for a song.
public enum ArtworkCommand: String, Sendable {
    /// Reads artwork from the song's folder.
    case albumArt = "albumart"
    /// Reads artwork embedded in the song file.
    case readPicture = "readpicture"

    /// The protocol feature that provides this command.
    var feature: ProtocolFeature {
        switch self {
        case .albumArt: .albumArt
        case .readPicture: .readPicture
        }
    }
}

/// Specifies the method for retrieving artwork from MPD.
public enum ArtworkGetter: String, Codable, Sendable {
    /// Retrieve artwork from the music library folder structure.
    case library = "albumart"
    /// Retrieve artwork embedded in the audio file.
    case metadata = "readpicture"
    /// Try library first, then fall back to metadata if not found.
    case libraryThenMetadata = "albumart_then_readpicture"
    /// Try metadata first, then fall back to library if not found.
    case metadataThenLibrary = "readpicture_then_albumart"

    /// Returns the ordered list of MPD commands to try for artwork retrieval.
    public var commands: [ArtworkCommand] {
        switch self {
        case .library: [.albumArt]
        case .metadata: [.readPicture]
        case .libraryThenMetadata: [.albumArt, .readPicture]
        case .metadataThenLibrary: [.readPicture, .albumArt]
        }
    }
}
