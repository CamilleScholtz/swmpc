//
//  PlaylistManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 20/06/2025.
//

import SwiftUI

/// Manages playlist operations for the MPD client.
@Observable final class PlaylistManager {
    private let state: LoadingState

    init(state: LoadingState) {
        self.state = state
    }

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
    func set(idle: Bool = true) async throws {
        let (allPlaylists, favorites) = try await fetchPlaylists(idle: idle)

        playlists = allPlaylists.filter { $0.name != "Favorites" }
        self.favorites = favorites
    }

    /// Fetches the playlists from the MPD server.
    ///
    /// - Parameter idle: Whether to use the idle connection.
    /// - Returns: A tuple containing the playlists and the songs in the
    ///            `Favorites` playlist.
    private func fetchPlaylists(idle: Bool) async throws -> ([Playlist], [Song]) {
        let allPlaylists = try await idle
            ? ConnectionManager.idle.getPlaylists()
            : ConnectionManager.command().getPlaylists()

        guard let favoritePlaylist = allPlaylists.first(where: {
            $0.name == "Favorites"
        }) else {
            return (allPlaylists, [])
        }

        let favorites = try await idle
            ? ConnectionManager.idle.getSongs(from: .playlist(favoritePlaylist))
            : ConnectionManager.command().getSongs(from: .playlist(favoritePlaylist))

        return (allPlaylists, favorites)
    }

    /// Gets songs for a specific playlist.
    func getSongs(for playlist: Playlist) async throws -> [Song] {
        defer { state.isLoading = false }

        return try await ConnectionManager.command().getSongs(from: .playlist(playlist))
    }
}
