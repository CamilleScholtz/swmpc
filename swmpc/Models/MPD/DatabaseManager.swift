//
//  DatabaseManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

/// Manages the MPD database, handling artists, albums, and song queries.
@Observable
final class DatabaseManager {
    /// The artists in the database with their albums.
    private(set) var albums: [Album]?

    /// Sets the media type and loads the appropriate data.
    ///
    /// - Parameters:
    ///   - idle: Whether to use the idle connection.
    /// - Throws: An error if the media could not be set.
    @MainActor
    func set(idle: Bool = false) async throws {
        albums = try await idle
            ? ConnectionManager.idle.getDatabase()
            : ConnectionManager.command().getDatabase()
    }
}
