//
//  ConnectionConfiguration.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import Synchronization

/// Holds the shared server configuration used by all connection managers.
///
/// This is separate from ConnectionManager because generic types cannot have
/// static stored properties.
public enum ConnectionConfiguration {
    private static let storage = Mutex<Server?>(nil)

    public static var server: Server? {
        get { storage.withLock { $0 } }
        set {
            storage.withLock { $0 = newValue }
            availableTags = nil
        }
    }

    private static let tagStorage = Mutex<Set<String>?>(nil)

    /// The tag types the selected server reports it supports, or `nil` until
    /// a connection has asked it.
    ///
    /// Held here rather than on a connection because command-mode
    /// connections last a single operation, and the answer is a property of
    /// the server, see ``ConnectionManager/narrowing(_:to:)``. Selecting a
    /// server clears it, since the next one may support a different set.
    static var availableTags: Set<String>? {
        get { tagStorage.withLock { $0 } }
        set { tagStorage.withLock { $0 = newValue } }
    }
}
