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
    func set(idle: Bool = true) async throws {        
        LoadingManager.shared.show()
        defer { LoadingManager.shared.hide() }

        let allPlaylists = try await idle
            ? ConnectionManager.idle.getPlaylists()
            : ConnectionManager.command().getPlaylists()

        playlists = allPlaylists.filter { $0.name != "Favorites" }

        guard let favoritePlaylist = allPlaylists.first(where: {
            $0.name == "Favorites"
        }) else {
            return
        }
        favorites = try await idle
            ? ConnectionManager.idle.getSongs(from:
                .playlist(favoritePlaylist))
            : ConnectionManager.command().getSongs(from:
                .playlist(favoritePlaylist))
    }

    /// Gets songs for a specific playlist, with caching
    @MainActor
    func getSongs(for playlist: Playlist) async throws -> [Song] {
        try await ConnectionManager.command().getSongs(from: .playlist(playlist))
    }
}
