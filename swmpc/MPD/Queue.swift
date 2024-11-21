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

    var media: [any Mediable] = []
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
            guard media.isEmpty || !(media is [Artist]) else {
                return
            }

            let albums = try! await commandManager.getAlbums()

            media = albums.reduce(into: [Artist]()) { result, album in
                if let index = result.firstIndex(where: { $0.name == album.artist }) {
                    result[index].add(albums: [album])
                } else {
                    result.append(Artist(
                        id: album.id,
                        artworkUri: album.artworkUri,
                        name: album.artist ?? "Unknown artist",
                        albums: [album]
                    ))
                }
            }
        case .song:
            guard media.isEmpty || !(media is [Song]) else {
                return
            }

            media = try! await commandManager.getSongs()
        default:
            guard media.isEmpty || !(media is [Album]) else {
                return
            }

            media = try! await commandManager.getAlbums()
        }
    }

    @MainActor
    func get(for uri: URL, using type: MediaType) async -> (any Mediable)? {
        await set(for: type)

        return media.first(where: { $0.uri == uri })
    }

    // TODO: just return something instead of settig search.
    @MainActor
    func search(for query: String, using type: MediaType) async {
        await set(for: type)

        switch type {
        case .artist:
            search = (media as! [Artist]).filter {
                $0.name.range(of: query, options: .caseInsensitive) != nil
            }
        case .song:
            search = (media as! [Song]).filter {
                $0.artist?.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title?.range(of: query, options: .caseInsensitive) != nil
            }
        default:
            search = (media as! [Album]).filter {
                $0.artist?.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title?.range(of: query, options: .caseInsensitive) != nil
            }
        }
    }
}
