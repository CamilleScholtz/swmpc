//
//  Destinations.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

import Navigator
import SFSafeSymbols

enum SidebarDestination: Hashable {
    case albums
    case artists
    case songs
    case playlist(Playlist)

    static var categories: [Self] {
        [.albums, .artists, .songs]
    }

    var type: MediaType {
        switch self {
        case .albums: .album
        case .artists: .artist
        case .songs: .song
        case .playlist: .playlist
        }
    }

    var label: String {
        switch self {
        case .albums: "Albums"
        case .artists: "Artists"
        case .songs: "Songs"
        case let .playlist(playlist): playlist.name
        }
    }

    var symbol: SFSymbol {
        switch self {
        case .albums: .squareStack
        case .artists: .musicMicrophone
        case .songs: .musicNote
        case .playlist: .musicNoteList
        }
    }
}

enum ContentDestination: Codable, Hashable {
    case album(Album)
    case artist(Artist)
}
