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
    ///            by the server response. Empty when the idle command was
    ///            cancelled via `noidle()` before any subsystem changed.
    /// - Throws: An error if writing the command or reading the response
    ///           fails.
    func idleForEvents(mask: [IdleEvent]) async throws -> [IdleEvent] {
        let lines = try await run(["idle \(mask.map(\.rawValue).joined(separator: " "))"])

        return lines.compactMap { line -> IdleEvent? in
            guard line.hasPrefix("changed: ") else {
                return nil
            }

            return IdleEvent(rawValue: String(
                line.dropFirst("changed: ".count),
            ))
        }
    }

    /// Cancels a pending `idleForEvents` call by sending `noidle`.
    ///
    /// MPD replies to the pending `idle` immediately — with any changed
    /// subsystems, or nothing — so this also serves as a liveness probe for
    /// the idle connection: on a socket that died silently (for example while
    /// the app was suspended), the write or the pending read fails, causing
    /// the owning update loop to tear down the connection and reconnect. A
    /// no-op when no idle command is pending.
    ///
    /// - Throws: An error if writing to the connection fails.
    func noidle() async throws {
        guard isCommandInFlight else {
            return
        }

        try await writeLine("noidle")
    }
}
