//
//  Queue.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

@Observable final class Queue {
//    init() {
//        Task {
//            try? await setPlaylists()
//            //try? await ConnectionManager().loadPlaylist(nil)
//        }
//    }

    private(set) var playlists: [Playlist]?

    private(set) var type: MediaType?
    private(set) var playlist: Playlist?

    private(set) var media: [any Mediable] = []
    private(set) var search: [any Mediable]?

    @MainActor
    func set(for type: MediaType? = nil, using playlist: Playlist? = nil) async throws {
        var type = type
        if type == nil {
            type = self.type
        }

        if self.playlist != playlist {
            self.playlist = playlist
            try await ConnectionManager().loadPlaylist(playlist)
        }

        guard self.type != type else {
            return
        }
        defer { self.type = type }

        switch type {
        case .artist:
            let albums = try await ConnectionManager().getAlbums()
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
            media = try await ConnectionManager().getSongs()
        case .playlist:
            media = try await ConnectionManager().getSongs(for: playlist)
        default:
            media = try await ConnectionManager().getAlbums()
        }
    }

    @MainActor
    func setSearch(for query: String, using type: MediaType) async throws {
        try await set(for: type)

        switch type {
        case .artist:
            search = (media as! [Artist]).filter {
                $0.name.range(of: query, options: .caseInsensitive) != nil
            }
        case .song:
            search = (media as! [Song]).filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        default:
            search = (media as! [Album]).filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        }
    }

    @MainActor
    func setPlaylists() async throws {
        playlists = try await ConnectionManager.shared.getPlaylists().filter { $0.name != "Favorites" }
    }

    @MainActor
    func clearSearch() {
        search = nil
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
