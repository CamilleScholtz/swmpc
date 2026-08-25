//
//  IdleModeCommands.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Commands specific to idle mode connections.
public extension ConnectionManager where Mode == IdleMode {
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
    ///            cancelled via `probe()` before any subsystem changed.
    /// - Throws: An error if writing the command or reading the response
    ///           fails.
    func idleForEvents(mask: [IdleEvent]) async throws -> [IdleEvent] {
        isIdlePending = true
        defer { isIdlePending = false }

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

    /// Cancels a pending `idleForEvents` call by sending `noidle`, and
    /// reports whether the connection answered.
    ///
    /// MPD replies to the pending `idle` immediately — with any changed
    /// subsystems, or nothing — so this doubles as a liveness probe for the
    /// idle connection: on a socket that died silently (for example while the
    /// app was suspended) the write fails outright, or, more often, succeeds
    /// into a send buffer that never drains and the parked read simply never
    /// returns. Waiting for that read to unpark is therefore the actual test,
    /// and a caller that is told `false` should throw the connection away
    /// rather than wait for TCP to time out.
    ///
    /// - Parameter timeout: How long to give the parked `idle` to return.
    /// - Returns: `true` if no `idle` was pending or the pending one returned
    ///            in time, `false` if the connection is unresponsive.
    func probe(timeout: Duration = .seconds(2)) async -> Bool {
        guard isIdlePending else {
            return true
        }

        do {
            try await writeLine("noidle")
        } catch {
            return false
        }

        let deadline = ContinuousClock.now.advanced(by: timeout)

        while isIdlePending {
            guard ContinuousClock.now < deadline else {
                return false
            }

            try? await Task.sleep(for: .milliseconds(50))
        }

        return true
    }
}
