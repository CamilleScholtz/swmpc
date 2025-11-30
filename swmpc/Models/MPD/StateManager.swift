//
//  StateManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/07/2025.
//

import Network
import SwiftUI

/// Manages the overall state of the MPD client including loading and connection
/// states.
@Observable final class StateManager {
    /// Whether the MPD client is currently loading data.
    var isLoading = true

    /// The current network connection state.
    var connectionState: NetworkChannel<TCP>.State?

    /// The most recent connection or communication error, if any.
    var error: Error?

    /// Whether the connection is ready and connected.
    var isConnectionReady: Bool {
        guard let state = connectionState else {
            return false
        }

        return state == .ready
    }

    /// The color representing the current connection state.
    var connectionColor: Color {
        guard let state = connectionState else {
            return .gray
        }

        switch state {
        case .ready:
            return .green
        case .failed:
            return .red
        case .waiting:
            return .red
        case .preparing:
            return .yellow
        case .setup:
            return .gray
        case .cancelled:
            return .gray
        @unknown default:
            return .gray
        }
    }

    /// A description of the current connection state.
    var connectionDescription: String {
        guard let state = connectionState else {
            return "Connection not initialized"
        }

        switch state {
        case .ready:
            return "Connected"
        case .failed:
            return "Connection failed"
        case .waiting:
            return "Trying to connect"
        case .preparing:
            return "Establishing connection"
        case .setup:
            return "Setting up connection"
        case .cancelled:
            return "Connection cancelled"
        @unknown default:
            return "Unknown state"
        }
    }
}
