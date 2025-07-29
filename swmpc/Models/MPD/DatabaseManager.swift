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

    /// The collection of currently loaded media items (e.g., albums, artists,
    /// or songs) based on the active `type`.
    private(set) var media: [any Mediable]?

    /// The current type of media being displayed or managed (e.g., albums, artists).
    /// Changing this property will automatically trigger a data refresh.
    var type: MediaType = .album {
        didSet {
            guard oldValue != type else {
                return
            }

            Task(priority: .userInitiated) {
                try? await set(idle: false)
            }
        }
    }

    /// The current sort option being used.
    /// Changing this property will automatically trigger a data refresh.
    var sort: SortDescriptor = .init(option: .artist) {
        didSet {
            guard oldValue != sort else {
                return
            }

            Task(priority: .userInitiated) {
                try? await set(idle: false)
            }
        }
    }

    /// Sets the media type and reloads the media data from the server.
    ///
    /// This method updates the `type` property and then calls `fetchMedia` to
    /// repopulate the `media` collection. It can be forced to reload even if
    /// the media type has not changed.
    ///
    /// - Parameters:
    ///   - idle: A Boolean indicating whether to use the long-lived idle
    ///           connection for the fetch, which is more efficient.
    /// - Throws: An error if fetching the media from the server fails.
    func set(idle: Bool = true)
        async throws
    {
        defer { state.isLoading = false }
        
        media = switch type {
        case .album:
            try await idle
            ? ConnectionManager.idle.getAlbums(sortBy: sort.option, direction: sort.direction)
            : ConnectionManager.command().getAlbums(sortBy: sort.option, direction: sort.direction)
        case .artist:
            try await idle
                ? ConnectionManager.idle.getArtists(sortBy: sort.option, direction: sort.direction)
                : ConnectionManager.command().getArtists(sortBy: sort.option, direction: sort.direction)
        case .song:
            try await idle
                ? ConnectionManager.idle.getSongs(from: Source.database, sortBy: sort.option, direction: sort.direction)
                : ConnectionManager.command().getSongs(from: Source.database, sortBy: sort.option, direction: sort.direction)
        case .playlist:
            nil
        }
    }
}
