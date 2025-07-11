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

    /// Cache of playlist songs by playlist ID
    private var playlistSongs: [String: [Song]] = [:]

    /// Cache of search results by playlist ID
    private var searchResults: [String: [Song]] = [:]

    /// This asynchronous function sets the playlists available on the server.
    /// It also sets the songs in the `Favorites` playlist.
    ///
    /// - Note: The `Favorites` playlist is filtered out of the playlists.
    ///
    /// - Throws: An error if the playlists could not be set.
    @MainActor
    func set(idle: Bool = true) async throws {
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
        let songs = try await ConnectionManager.command().getSongs(from: .playlist(playlist))
        playlistSongs[playlist.id] = songs
        return songs
    }

    /// Gets cached songs for a playlist (or search results if searching)
    func songs(for playlist: Playlist) -> [Song] {
        if let results = searchResults[playlist.id] {
            return results
        }
        return playlistSongs[playlist.id] ?? []
    }

    /// Searches for songs in a playlist
    func search(for query: String, in playlist: Playlist) {
        guard let songs = playlistSongs[playlist.id] else {
            searchResults.removeValue(forKey: playlist.id)
            return
        }

        if query.isEmpty {
            searchResults.removeValue(forKey: playlist.id)
        } else {
            searchResults[playlist.id] = songs.filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        }
    }

    /// Clears search results for a playlist
    func clearSearch(for playlist: Playlist) {
        searchResults.removeValue(forKey: playlist.id)
    }

    /// Refreshes songs for a playlist
    @MainActor
    func refreshPlaylist(_ playlist: Playlist) async throws {
        _ = try await getSongs(for: playlist)
    }
}
