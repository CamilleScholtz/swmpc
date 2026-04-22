//
//  ConnectionState.swift
//  MPDKit
//
//  Created by Camille Scholtz on 22/04/2026.
//

import Network

/// A framework-agnostic representation of the underlying network connection's
/// lifecycle. Mirrors the cases of `NetworkConnection.State` but keeps the
/// `Network` framework out of consumers' import lists.
public enum ConnectionState: Sendable, Equatable {
    case setup
    case preparing
    case ready
    case waiting(reason: String, isRefused: Bool)
    case failed(reason: String)
    case cancelled

    init(_ state: NetworkConnection<TCP>.State) {
        switch state {
        case .setup:
            self = .setup
        case .preparing:
            self = .preparing
        case .ready:
            self = .ready
        case let .waiting(error):
            var refused = false
            if case let .posix(code) = error, code == .ECONNREFUSED {
                refused = true
            }
            self = .waiting(
                reason: error.localizedDescription,
                isRefused: refused,
            )
        case let .failed(error):
            self = .failed(reason: error.localizedDescription)
        case .cancelled:
            self = .cancelled
        @unknown default:
            self = .setup
        }
    }

    /// Whether this state should cause the connection manager to drop its
    /// underlying connection (so the caller can attempt to reconnect).
    var requiresDisconnect: Bool {
        switch self {
        case .failed, .waiting(_, isRefused: true):
            true
        default:
            false
        }
    }
}
