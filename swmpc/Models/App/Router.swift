//
//  Router.swift
//  swmpc
//
//  Created by Camille Scholtz on 25/02/2025.
//

import Navigator
import SFSafeSymbols
import SwiftUI

struct Category: Identifiable, Hashable {
    var id: String { label }

    let type: MediaType
    let playlist: Playlist?
    let label: String
    let image: SFSymbol
}

@Observable class Router {
    let categories: [Category] = [
        .init(type: MediaType.album, playlist: nil, label: "Albums", image: .squareStack),
        .init(type: MediaType.artist, playlist: nil, label: "Artists", image: .musicMicrophone),
        .init(type: MediaType.song, playlist: nil, label: "Songs", image: .musicNote),
    ]

    var playlists: [Category] = [
        .init(type: MediaType.playlist, playlist: Playlist(name: "Favorites"), label: "Favorites", image: .heart),
    ]

    var category: Category {
        didSet {
            previousCategory = oldValue
        }
    }

    var previousCategory: Category
    var path = NavigationPath()

    @MainActor
    init() {
        category = categories.first!
        previousCategory = categories.first!
    }

    @MainActor
    func setPlaylists(_ playlists: [Playlist]) {
        self.playlists.removeSubrange(1...)

        self.playlists.append(contentsOf: playlists.map {
            .init(type: MediaType.playlist, playlist: $0, label: $0.name, image: .musicNoteList)
        })
    }
}
