//
//  Queue.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

@Observable final class Queue {
    var media: [any Mediable] = []

    var type: MediaType?
    var playlists: [Playlist]?
    var favorites: [Song] = []

    // TODO: Move this to the view.
    var query: String = ""
    
    @MainActor
    func set(using type: MediaType? = nil) async throws {
        let current = type ?? self.type
        guard current != self.type else {
            return
        }
        
        defer { self.type = current }
        
        switch type {
        case .artist:
            media = try await ConnectionManager.command().getArtists()
        case .song, .playlist:
            media = try await ConnectionManager.command().getSongs()
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
        favorites = try await ConnectionManager.idle.getSongs(for: favoritePlaylist)
    }

    @MainActor
    func search(for query: String, using type: MediaType) async throws -> [any Mediable] {
        //try await set(using: type, for: playlist)

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
    func get(using: MediaType, for media: any Mediable) async throws -> (any Mediable)? {
        guard type != .song else {
            return media
        }

        try await set(using: type)

        if let index = self.media.firstIndex(where: { $0.id > media.id }), index > 0 {
            return self.media[index - 1]
        }

        return nil
    }
}
