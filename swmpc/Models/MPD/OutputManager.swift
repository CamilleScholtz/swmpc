//
//  OutputManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 15/12/2025.
//

import MPDKit
import Observation

/// Manages MPD audio outputs.
///
/// This class maintains the list of available audio outputs and provides
/// methods to enable, disable, or toggle them. It automatically synchronizes
/// with the MPD server when output changes are detected.
@Observable final class OutputManager {
    /// The list of available audio outputs.
    private(set) var outputs: [Output] = []

    /// Returns only the httpd outputs from the available outputs.
    var httpd: [Output] {
        outputs.filter(\.isHttpd)
    }

    /// Two-way access to an output's enabled state, usable as a key path
    /// binding (`$outputs[isEnabled: output]`). Setting the value toggles the
    /// output on the server and refreshes the outputs list.
    subscript(isEnabled output: Output) -> Bool {
        get {
            outputs.first { $0.id == output.id }?.isEnabled ?? output.isEnabled
        }
        set {
            guard newValue != self[isEnabled: output] else {
                return
            }

            Task(priority: .userInitiated) {
                try? await ConnectionManager.command { [self] connection in
                    try await connection.toggleOutput(output)
                    try await set(on: connection)
                }
            }
        }
    }

    /// Updates the outputs list from the MPD server.
    ///
    /// - Parameter connection: The connection to load over.
    /// - Throws: An error if fetching the outputs fails.
    func set<Mode: ConnectionMode>(on connection: ConnectionManager<Mode>)
        async throws
    {
        outputs = try await connection.getOutputs()
    }
}
