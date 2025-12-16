//
//  ConnectionError.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import Foundation

/// Errors that can occur during MPD connection management.
public enum ConnectionManagerError: LocalizedError, Equatable {
    case invalidHost
    case invalidPort
    case unsupportedServerVersion

    case connectionFailure(String)
    case connectionUnexpectedClosure

    case readUntilConditionNotMet

    case protocolViolation(String)
    case malformedResponse(String)
    case unsupportedOperation(String)

    public nonisolated var errorDescription: String? {
        switch self {
        case .invalidHost:
            "Invalid host provided."
        case .invalidPort:
            "Invalid port provided. Port must be between 1 and 65535."
        case .unsupportedServerVersion:
            "Unsupported MPD server version. Minimum required version is 0.22."
        case let .connectionFailure(details):
            "Network connection returned an error: \(details)"
        case .connectionUnexpectedClosure:
            "Network connection was closed unexpectedly during operation."
        case .readUntilConditionNotMet:
            "Failed to locate expected response termination sequence."
        case let .protocolViolation(details):
            "MPD protocol violation: \(details)"
        case let .malformedResponse(details):
            "Received malformed or unexpected response format from server: \(details)"
        case let .unsupportedOperation(details):
            "Unsupported operation attempted: \(details)"
        }
    }
}
