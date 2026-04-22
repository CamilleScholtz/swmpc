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
        set { storage.withLock { $0 = newValue } }
    }
}
