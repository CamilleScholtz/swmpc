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

    var search: [Any]?

    @MainActor
    init(idleManager: ConnectionManager, commandManager: ConnectionManager) {
        self.idleManager = idleManager
        self.commandManager = commandManager
    }

    // TODO: This gets called twice on startup?
    @MainActor
    func set(using type: MediaType) async {
        search = nil

        switch type {
        case .album:
            guard albums.isEmpty else {
                return
            }

            albums = await commandManager.getAlbums()
        case .artist:
            guard artists.isEmpty else {
                return
            }

            if albums.isEmpty {
                await set(using: .album)
            }

            artists = albums.reduce(into: [Artist]()) { result, album in
                if let index = result.firstIndex(where: { $0.name == album.artist }) {
                    result[index].albums.append(album)
                } else {
                    result.append(Artist(
                        id: album.id,
                        name: album.artist ?? "Unknown artist",
                        albums: [album]
                    ))
                }
            }
        default:
            guard songs.isEmpty else {
                return
            }

            songs = await commandManager.getSongs()
        }
    }

    @MainActor
    func search(for query: String, using type: MediaType) async {
        switch type {
        case .album:
            if albums.isEmpty {
                await set(using: .album)
            }

            search = albums.filter {
                $0.artist?.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title?.range(of: query, options: .caseInsensitive) != nil
            }
        case .artist:
            if artists.isEmpty {
                await set(using: .artist)
            }

            search = artists.filter {
                $0.name.range(of: query, options: .caseInsensitive) != nil
            }
        default:
            print("D")
        }
    }
}
