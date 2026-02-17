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

    /// Waits for an idle event from the media server that matches the specified
    /// mask.
    ///
    /// - Parameter mask: An array of `IdleEvent` values specifying which events
    ///                   to listen for.
    /// - Returns: The `IdleEvent` that triggered the idle state, as indicated
    ///            by the server response.
    /// - Throws: A `ConnectionManagerError.malformedResponse` if the server
    ///           response does not contain a `changed` line.
    func idleForEvents(mask: [IdleEvent]) async throws -> IdleEvent {
        let lines = try await run(["idle \(mask.map(\.rawValue).joined(separator: " "))"])
        guard let changedLine = lines.first(where: { $0.hasPrefix(
            "changed: ",
        ) })
        else {
            throw ConnectionManagerError.malformedResponse(
                "Missing 'changed' line",
            )
        }

        let changed = String(changedLine.dropFirst("changed: ".count))
        guard let event = IdleEvent(rawValue: changed) else {
            throw ConnectionManagerError.malformedResponse(
                "Received unknown idle event: \(changed)",
            )
        }

        return event
    }
}
