//
//  IdleModeCommands.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Commands specific to idle mode connections.
public extension ConnectionManager where Mode == IdleMode {
    /// Shared singleton instance for idle connection management.
    /// Used for listening to server events without blocking other operations.
    static let idle = ConnectionManager<IdleMode>()

    /// Waits for idle events from the media server that match the specified
    /// mask.
    ///
    /// A single idle response can report multiple changed subsystems (one
    /// `changed:` line each); all of them are returned. Unknown subsystems
    /// are ignored for forward compatibility.
    ///
    /// - Parameter mask: An array of `IdleEvent` values specifying which events
    ///                   to listen for.
    /// - Returns: The `IdleEvent`s that triggered the idle state, as indicated
    ///            by the server response.
    /// - Throws: A `ConnectionManagerError.malformedResponse` if the server
    ///           response does not contain any known `changed` line.
    func idleForEvents(mask: [IdleEvent]) async throws -> [IdleEvent] {
        let lines = try await run(["idle \(mask.map(\.rawValue).joined(separator: " "))"])

        let events = lines.compactMap { line -> IdleEvent? in
            guard line.hasPrefix("changed: ") else {
                return nil
            }

            return IdleEvent(rawValue: String(
                line.dropFirst("changed: ".count),
            ))
        }

        guard !events.isEmpty else {
            throw ConnectionManagerError.malformedResponse(
                "Missing 'changed' line",
            )
        }

        return events
    }
}
