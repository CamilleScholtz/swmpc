//
//  DatabaseManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

/// Manages the MPD database, handling artists, albums, and song queries.
@Observable final class DatabaseManager {
    /// The loading state manager, used to indicate when data is being fetched.
    private let state: LoadingState

    /// Creates a new database manager.
    ///
    /// - Parameter state: An instance of `LoadingState` to report back loading
    ///                    activity for UI updates.
    init(state: LoadingState) {
        self.state = state
    }

    /// The current type of media being displayed or managed (e.g., albums,
    /// artists).
    private(set) var type: MediaType = .album

    /// The collection of currently loaded media items (e.g., albums, artists,
    /// or songs) based on the active `type`.
    private(set) var media: [any Mediable]?

    /// Sets the media type and reloads the media data from the server.
    ///
    /// This method updates the `type` property and then calls `fetchMedia` to
    /// repopulate the `media` collection. It can be forced to reload even if
    /// the media type has not changed.
    ///
    /// - Parameters:
    ///   - type: The new type of media to load. If `nil`, the current set type
    ///           is used.
    ///   - idle: A Boolean indicating whether to use the long-lived idle
    ///           connection for the fetch, which is more efficient.
    ///   - force: A Boolean indicating whether to force a reload even if the
    ///            `type` is the same as the current one.
    /// - Throws: An error if fetching the media from the server fails.
    func set(type: MediaType? = nil, idle: Bool = true, force: Bool = false)
        async throws
    {
        defer { state.isLoading = false }

        guard type != self.type || force else {
            return
        }

        if let type {
            self.type = type
        }

        media = try await fetchMedia(idle: idle)
    }

    /// Fetches media from the MPD server based on the current `type`.
    ///
    /// This function dispatches the appropriate `ConnectionManager` command to
    /// retrieve albums, artists, or songs.
    ///
    /// - Parameter idle: A Boolean indicating whether to use the long-lived
    ///                   idle connection, which is more efficient.
    /// - Returns: An array of `Mediable` items, or `nil` if the current media
    ///            type is not supported for database fetching (e.g.,
    ///            `.playlist`).
    /// - Throws: An error if the connection to the server or data retrieval
    ///           fails.
    private func fetchMedia(idle: Bool) async throws -> [any Mediable]? {
        switch type {
        case .album:
            return try await idle
                ? ConnectionManager.idle.getDatabase()
                : ConnectionManager.command().getDatabase()
        case .artist:
            let albums = try await idle
                ? ConnectionManager.idle.getDatabase()
                : ConnectionManager.command().getDatabase()

            return Dictionary(grouping: albums.compactMap(\.artist), by: {
                $0.name
            }).values.compactMap(\.first)
        case .song:
            return try await idle
                ? ConnectionManager.idle.getSongs(from: Source.database)
                : ConnectionManager.command().getSongs(from: Source.database)
        case .playlist:
            return nil
        }
    }
}
