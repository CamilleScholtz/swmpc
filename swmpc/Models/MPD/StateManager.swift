//
//  StateManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/07/2025.
//

import Network
import SwiftUI

/// Manages the overall state of the MPD client including loading and connection states.
@Observable final class StateManager {
    /// Whether the MPD client is currently loading data.
    var isLoading = false

    /// The current network connection state.
    var connectionState: NetworkChannel<TCP>.State?

    /// The most recent connection or communication error, if any.
    var error: EquatableError?

    /// Whether the connection is ready and connected.
    var isConnectionReady: Bool {
        guard let state = connectionState else {
            return false
        }

        return state == .ready
    }
}
