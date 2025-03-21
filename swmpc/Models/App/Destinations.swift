//
//  Destinations.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SwiftUI

import NavigatorUI
import SFSafeSymbols

enum SidebarDestination: Identifiable, Codable, Hashable {
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
        case .albums: String(localized: "Albums")
        case .artists: String(localized: "Artists")
        case .songs: String(localized: "Songs")
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

enum ContentDestination: Identifiable, Codable, Hashable {
    case album(Album)
    case artist(Artist)
}
