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
    private let state: LoadingState

    init(state: LoadingState) {
        self.state = state
    }

    private(set) var type: MediaType = .album

    /// The media in the database.
    private(set) var media: [any Mediable]?

    /// Sets the media type and loads the appropriate data.
    ///
    /// - Parameters:
    ///   - type: The type of media to load.
    ///   - idle: Whether to use the idle connection.
    ///   - force: Whether to force the update even if the type is unchanged.
    /// - Throws: An error if the media could not be set.
    @MainActor
    func set(type: MediaType? = nil, idle: Bool = true, force: Bool = false) async throws {
        defer { state.setLoading(false, for: .database) }

        guard type != self.type || force else {
            return
        }

        if let type {
            self.type = type
        }

        media = nil

        switch self.type {
        case .album:
            media = try await idle
                ? ConnectionManager.idle.getDatabase()
                : ConnectionManager.command().getDatabase()
        case .artist:
            let fetchedAlbums = try await idle
                ? ConnectionManager.idle.getDatabase()
                : ConnectionManager.command().getDatabase()

            if let fetchedAlbums {
                let artistDict = Dictionary(grouping: fetchedAlbums.compactMap(\.artist), by: {
                    $0.name
                })
                let artists = artistDict.values.compactMap(\.first).sorted {
                    $0.name < $1.name
                }
                media = artists
            } else {
                media = nil
            }
        case .song:
            media = try await idle
                ? ConnectionManager.idle.getSongs(from: Source.database)
                : ConnectionManager.command().getSongs(from: Source.database)
        case .playlist:
            break
        }
    }
}
