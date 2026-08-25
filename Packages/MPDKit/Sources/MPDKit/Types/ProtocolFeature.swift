//
//  ProtocolFeature.swift
//  MPDKit
//
//  Created by Camille Scholtz on 25/08/2026.
//

/// Compares the protocol version strings MPD announces in its greeting, such
/// as `"0.23.5"`.
public enum ProtocolVersion {
    /// The oldest protocol version this library talks to.
    ///
    /// Chosen for Mopidy, which announces `0.19.0` and means it. Below this
    /// the protocol lacks the tags the app is built around, leaving nothing
    /// worth showing.
    public static let minimum = "0.19"

    /// Returns whether a known `version` is no older than `minimum`.
    ///
    /// - Parameters:
    ///   - minimum: The version to compare against, e.g. `"0.24"`.
    ///   - version: The version announced by the server, or `nil` when it is
    ///              not yet known.
    /// - Returns: `true` if the version is known and not older than
    ///            `minimum`.
    public static func isAtLeast(_ minimum: String, in version: String?)
        -> Bool
    {
        guard let version else {
            return false
        }

        return version.compare(minimum, options: .numeric) != .orderedAscending
    }
}

/// A protocol feature that MPD gained in a specific release.
///
/// Support is decided purely from the version in the server greeting, and a
/// server is taken at its word. Announcing an old version honestly — as
/// Mopidy does with `0.19.0` — is something to degrade around; announcing a
/// version whose commands are then missing is a bug to report upstream, not
/// something to probe for.
public enum ProtocolFeature: Sendable {
    /// The filter expression syntax for `find` and `search`, e.g.
    /// `"(Artist == 'x')"`, including negation and `AND`. Older servers take
    /// a flat sequence of `Artist "x"` pairs, combined with an implicit
    /// `AND`, and cannot express negation at all.
    case filterExpressions

    /// The `sort` parameter on `find` and `search`.
    case sort

    /// The `sort` parameter on `playlistfind` and `playlistsearch`.
    case queueSort

    /// The `albumart` command, which reads artwork from the song's folder.
    case albumArt

    /// The `readpicture` command, which reads artwork embedded in the song.
    case readPicture

    /// The `binarylimit` command, which raises the binary chunk size.
    case binaryLimit

    /// The version that introduced this feature.
    public var minimumVersion: String {
        switch self {
        case .filterExpressions, .sort, .albumArt: "0.21"
        case .readPicture: "0.22"
        case .binaryLimit: "0.22.4"
        case .queueSort: "0.24"
        }
    }
}
