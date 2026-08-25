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
    /// Try library first, then fall back to metadata if not found.
    case libraryThenMetadata = "albumart_then_readpicture"
    /// Try metadata first, then fall back to library if not found.
    case metadataThenLibrary = "readpicture_then_albumart"

    /// Returns the ordered list of MPD commands to try for artwork retrieval.
    public var commands: [String] {
        switch self {
        case .library: ["albumart"]
        case .metadata: ["readpicture"]
        case .libraryThenMetadata: ["albumart", "readpicture"]
        case .metadataThenLibrary: ["readpicture", "albumart"]
        }
    }
}
