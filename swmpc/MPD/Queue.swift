//
//  Queue.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import libmpdclient
import SwiftUI

@Observable final class Queue {
    private let idleManager: ConnectionManager
    private let commandManager: ConnectionManager

    var albums: [Album] = []
    var artists: [Artist] = []
    var songs: [Song] = []

    var search: [any Mediable]?

    @MainActor
    init(idleManager: ConnectionManager, commandManager: ConnectionManager) {
        self.idleManager = idleManager
        self.commandManager = commandManager
    }

    // TODO: This gets called twice on startup?
    @MainActor
    func set(for type: MediaType) async {
        search = nil

        switch type {
        case .artist:
            guard artists.isEmpty else {
                return
            }

            if albums.isEmpty {
                await set(for: .album)
            }

            artists = albums.reduce(into: [Artist]()) { result, album in
                if let index = result.firstIndex(where: { $0.name == album.artist }) {
                    result[index].add(albums: [album])
                } else {
                    result.append(Artist(
                        id: album.id,
                        uri: album.uri,
                        name: album.artist ?? "Unknown artist",
                        albums: [album]
                    ))
                }
            }
        case .song:
            guard songs.isEmpty else {
                return
            }
            
            print("TODO")
        default:
            guard albums.isEmpty else {
                return
            }

            albums = try! await commandManager.getAlbums()
        }
    }

    @MainActor
    func search(for query: String, using type: MediaType) async {
        switch type {
        case .artist:
            if artists.isEmpty {
                await set(for: .artist)
            }

            search = artists.filter {
                $0.name.range(of: query, options: .caseInsensitive) != nil
            }
        case .song:
            print("TODO")
        default:
            if albums.isEmpty {
                await set(for: .album)
            }

            search = albums.filter {
                $0.artist?.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title?.range(of: query, options: .caseInsensitive) != nil
            }
        }
    }
}
