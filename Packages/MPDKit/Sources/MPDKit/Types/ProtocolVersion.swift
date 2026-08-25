//
//  ProtocolVersion.swift
//  MPDKit
//
//  Created by Camille Scholtz on 25/08/2026.
//

/// Compares the protocol version strings MPD announces in its greeting, such
/// as `"0.23.5"`.
///
/// `ConnectionManager` has its own `isVersionAtLeast` for gating commands.
/// This exists so the same comparison can be made outside the actor, where
/// views decide whether to offer an option the server is too old to honour.
public enum ProtocolVersion {
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
