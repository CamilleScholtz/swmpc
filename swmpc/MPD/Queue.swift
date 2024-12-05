//
//  Queue.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import libmpdclient
import SwiftUI

@Observable final class Queue {
    init() {
        Task {
            try? await CommandManager.shared.loadPlaylist(nil)
        }
    }
    
    let categories: [Category] = [
        .init(id: MediaType.album, label: "Albums", image: "square.stack"),
        .init(id: MediaType.artist, label: "Artists", image: "music.microphone"),
        .init(id: MediaType.song, label: "Songs", image: "music.note"),
        .init(id: MediaType.playlist, label: "Playlists", image: "music.note.list", list: false),
    ]

    var label: String {
        categories.first { $0.id == type }?.label ?? ""
    }

    var image: String {
        categories.first { $0.id == type }?.image ?? ""
    }

    private(set) var type: MediaType?
    private(set) var playlist: Playlist?
    private(set) var media: [any Mediable] = []
    private(set) var search: [any Mediable]?

    @MainActor
    func set(for type: MediaType, using playlist: Playlist? = nil) async {
        if self.playlist != playlist {
            self.playlist = playlist
            try? await CommandManager.shared.loadPlaylist(playlist)
        }
        
        guard self.type != type else  {
            return
        }
        self.type = type
        
        switch type {
        case .artist:
            guard let albums = try? await CommandManager.shared.getAlbums() else {
                return
            }
            let albumsByArtist = Dictionary(grouping: albums, by: { $0.artist })

            media = albumsByArtist.map { artist, albums in
                Artist(
                    id: albums.first!.id,
                    name: artist,
                    albums: albums
                )
            }
            .sorted { $0.name < $1.name }
        case .song:
            media = await (try? CommandManager.shared.getSongs()) ?? []
        case .playlist:
            media = await (try? CommandManager.shared.getSongs(for: playlist)) ?? []
        default:
            media = await (try? CommandManager.shared.getAlbums()) ?? []
        }
    }

    @MainActor
    func setSearch(for query: String, using type: MediaType) async {
        // await set(for: type)

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
    func get(for type: MediaType, using media: any Mediable) async -> (any Mediable)? {
        guard type != .song else {
            return media
        }
        
        await set(for: type, using: playlist)

        if let index = self.media.firstIndex(where: { $0.id > media.id }), index > 0 {
            return self.media[index - 1]
        }

        return nil
    }
}
