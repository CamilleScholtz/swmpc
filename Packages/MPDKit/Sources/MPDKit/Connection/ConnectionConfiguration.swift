//
//  ConnectionConfiguration.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Holds the shared server configuration used by all connection managers.
///
/// This is separate from ConnectionManager because generic types cannot have
/// static stored properties.
public enum ConnectionConfiguration {
    public nonisolated(unsafe) static var server: Server?
}
