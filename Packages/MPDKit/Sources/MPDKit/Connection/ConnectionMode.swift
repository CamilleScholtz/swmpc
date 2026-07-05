//
//  ConnectionMode.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Protocol defining the configuration for different connection modes to the
/// MPD server. Each mode determines its read buffer size and which commands
/// are available on the connection.
public protocol ConnectionMode: Sendable {
    /// The buffer size to use for reading data.
    nonisolated static var bufferSize: Int { get }
}

/// Connection mode for long-lived connections that listen for MPD server
/// events via the `idle` command.
public nonisolated enum IdleMode: ConnectionMode {
    public static let bufferSize = 4096
}

/// Connection mode for artwork retrieval operations.
/// Uses a larger buffer for efficient binary data transfer.
public nonisolated enum ArtworkMode: ConnectionMode {
    public static let bufferSize = 8192
}

/// Connection mode for executing MPD commands.
public nonisolated enum CommandMode: ConnectionMode {
    public static let bufferSize = 4096
}
