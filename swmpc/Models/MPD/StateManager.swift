//
//  StateManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/07/2025.
//

import MPDKit
import SwiftUI

/// Manages the overall state of the MPD client including loading and connection
/// states.
@Observable final class StateManager {
    /// Whether the MPD client is currently loading data.
    var isLoading = true

    /// The current network connection state.
    var connectionState: ConnectionState?

    /// The most recent connection or communication error, if any.
    var error: Error?

    /// The protocol version announced by the connected server, if any.
    ///
    /// Views gate options the server is too old to fill on this, rather than
    /// offering settings that can never match anything.
    var protocolVersion: String?

    /// Returns whether the connected server announces a version new enough to
    /// provide the given feature.
    ///
    /// Optimistic while disconnected, so the UI does not flicker options away
    /// between connections.
    ///
    /// - Parameter minimum: The version to compare against, e.g. `"0.24"`.
    /// - Returns: `true` if the version is unknown or new enough.
    func supports(minimumVersion minimum: String?) -> Bool {
        guard let minimum, protocolVersion != nil else {
            return true
        }

        return ProtocolVersion.isAtLeast(minimum, in: protocolVersion)
    }

    /// Whether the connection is ready and connected.
    var isConnectionReady: Bool {
        connectionState == .ready
    }

    /// The color representing the current connection state.
    var connectionColor: Color {
        guard let state = connectionState else {
            return .gray
        }

        switch state {
        case .ready:
            return .green
        case .failed, .waiting:
            return .red
        case .preparing:
            return .yellow
        case .setup, .cancelled:
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
        }
    }
}
