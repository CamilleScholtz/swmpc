//
//  Queue.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

@Observable final class Queue {
    private var internalMedia: [any Mediable] = []

    var media: [any Mediable] {
        get {
            results ?? internalMedia
        }
        set {
            internalMedia = newValue
        }
    }

    var results: [any Mediable]?

    private(set) var type: MediaType?
    private(set) var playlists: [Playlist]?
    private(set) var favorites: [Song] = []

    @MainActor
    func set(using type: MediaType? = nil) async throws {
        let current = type ?? self.type
        guard current != self.type else {
            return
        }

        defer { self.type = current }

        media = switch type {
        case .artist:
            try await ConnectionManager.command().getArtists()
        case .song, .playlist:
            try await ConnectionManager.command().getSongs()
        default:
            try await ConnectionManager.command().getAlbums()
        }
    }

    @MainActor
    func setPlaylists() async throws {
        let allPlaylists = try await ConnectionManager.idle.getPlaylists()

        playlists = allPlaylists.filter { $0.name != "Favorites" }
        guard let favoritePlaylist = allPlaylists.first(where: { $0.name == "Favorites" }) else {
            return
        }
        favorites = try await ConnectionManager.idle.getSongs(for: favoritePlaylist)
    }

    @MainActor
    func search(for query: String, using type: MediaType? = nil) async throws {
        let current = type ?? self.type
        try await set(using: current)

        results = switch current {
        case .artist:
            (internalMedia as! [Artist]).filter {
                $0.name.range(of: query, options: .caseInsensitive) != nil
            }
        case .song:
            (internalMedia as! [Song]).filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        default:
            (internalMedia as! [Album]).filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        }
    }

    @MainActor
    func get(for media: any Mediable, using type: MediaType? = nil) async throws -> (any Mediable)? {
        let current = type ?? self.type
        guard current != .song else {
            return media
        }

        var queue: [any Mediable] = if current == self.type {
            internalMedia
        } else {
            switch type {
            case .artist:
                try await ConnectionManager.command().getArtists()
            case .song, .playlist:
                try await ConnectionManager.command().getSongs()
            default:
                try await ConnectionManager.command().getAlbums()
            }
        }

        if let index = queue.firstIndex(where: { $0.id > media.id }), index > 0 {
            return self.media[index - 1]
        }

        return nil
    }
}
