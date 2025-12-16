//
//  ConnectionMode.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// Protocol defining the configuration for different connection modes to the
/// MPD server. Each mode can have different performance characteristics and
/// buffer sizes.
public protocol ConnectionMode: Sendable {
    /// The buffer size to use for reading data.
    nonisolated static var bufferSize: Int { get }
}

/// Connection mode for idle operations that listen for MPD server events.
/// Uses keepalive to maintain long-lived connections.
public nonisolated enum IdleMode: ConnectionMode {
    public static let bufferSize = 4096
}

/// Connection mode for artwork retrieval operations.
/// Uses larger buffers and concurrent queue for efficient image data transfer.
public nonisolated enum ArtworkMode: ConnectionMode {
    public static let bufferSize = 8192
}

/// Connection mode for executing MPD commands.
/// Optimized for quick command execution with higher priority.
public nonisolated enum CommandMode: ConnectionMode {
    public static let bufferSize = 4096
}
