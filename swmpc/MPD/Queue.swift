//
//  Queue.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

@Observable final class Queue {
    private(set) var media: [any Mediable] = []

    private(set) var type: MediaType?
    private(set) var playlist: Playlist?

    private(set) var playlists: [Playlist]?
    private(set) var favorites: [Song] = []

    @MainActor
    func set(for type: MediaType? = nil, using playlist: Playlist? = nil) async throws {
        var type = type
        if type == nil {
            type = self.type
        } else if type == .playlist {
            type = .song
        }

        guard self.type != type || self.playlist != playlist else {
            return
        }

        if self.playlist != playlist {
            try await ConnectionManager.command().loadPlaylist(playlist)
        }

        defer {
            self.type = type
            self.playlist = playlist
        }

        switch type {
        case .artist:
            let albums = try await ConnectionManager.command().getAlbums()
            let albumsByArtist = Dictionary(grouping: albums, by: { $0.artist })

            media = albumsByArtist.map { artist, albums in
                Artist(
                    id: albums.first!.id,
                    position: albums.first!.position,
                    name: artist,
                    albums: albums
                )
            }
            .sorted { $0.position < $1.position }
        case .song:
            media = try await ConnectionManager.command().getSongs()
        case .playlist:
            media = try await ConnectionManager.command().getSongs(for: playlist)
        default:
            media = try await ConnectionManager.command().getAlbums()
        }
    }

    @MainActor
    func setPlaylists() async throws {
        let allPlaylists = try await ConnectionManager.idle.getPlaylists()

        playlists = allPlaylists.filter { $0.name != "Favorites" }
        guard let favoritePlaylist = allPlaylists.first(where: { $0.name == "Favorites" }) else {
            return
        }
        favorites = try await ConnectionManager.idle.getPlaylist(favoritePlaylist)
    }

    @MainActor
    func search(for query: String, using type: MediaType) async throws -> [any Mediable] {
        try await set(for: type)

        switch type {
        case .artist:
            return (media as! [Artist]).filter {
                $0.name.range(of: query, options: .caseInsensitive) != nil
            }
        case .song:
            return (media as! [Song]).filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        default:
            return (media as! [Album]).filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        }
    }

    @MainActor
    func get(for type: MediaType, using media: any Mediable) async throws -> (any Mediable)? {
        guard type != .song else {
            return media
        }

        try await set(for: type, using: playlist)

        if let index = self.media.firstIndex(where: { $0.id > media.id }), index > 0 {
            return self.media[index - 1]
        }

        return nil
    }
}
