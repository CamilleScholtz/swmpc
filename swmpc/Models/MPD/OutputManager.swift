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
                try? await ConnectionManager.command {
                    try await $0.toggleOutput(output)
                }

                try? await self.set(idle: false)
            }
        }
    }

    /// Updates the outputs list from the MPD server.
    ///
    /// - Parameter idle: Whether to use the idle connection or a command
    ///   connection.
    /// - Throws: An error if fetching the outputs fails.
    func set(idle: Bool = true) async throws {
        outputs = idle
            ? try await ConnectionManager.idle.getOutputs()
            : try await ConnectionManager.command {
                try await $0.getOutputs()
            }
    }
}
