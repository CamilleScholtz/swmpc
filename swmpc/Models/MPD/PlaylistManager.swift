//
//  PlaylistManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 20/06/2025.
//

import SwiftUI

/// Manages playlist operations for the MPD client.
@Observable
final class PlaylistManager {
    /// The playlists available on the server.
    private(set) var playlists: [Playlist]?

    /// The songs in the `Favorites` playlist.
    private(set) var favorites: [Song] = []

    /// This asynchronous function sets the playlists available on the server.
    /// It also sets the songs in the `Favorites` playlist.
    ///
    /// - Note: The `Favorites` playlist is filtered out of the playlists.
    ///
    /// - Throws: An error if the playlists could not be set.
    @MainActor
    func set() async throws {
        let allPlaylists = try await ConnectionManager.idle.getPlaylists()

        playlists = allPlaylists.filter { $0.name != "Favorites" }

        guard let favoritePlaylist = allPlaylists.first(where: {
            $0.name == "Favorites"
        }) else {
            return
        }

        favorites = try await ConnectionManager.idle.getSongs(for:
            favoritePlaylist)
    }
}
