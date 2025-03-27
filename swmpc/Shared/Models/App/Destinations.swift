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

    #if os(iOS)
        case playlists
    #endif

    static var categories: [Self] {
        #if os(iOS)
            [.albums, .artists, .songs, .playlists]
        #elseif os(macOS)
            [.albums, .artists, .songs]
        #endif
    }

    var type: MediaType {
        switch self {
        case .albums: .album
        case .artists: .artist
        case .songs: .song
        case .playlist: .playlist

        #if os(iOS)
            case .playlists: .playlist
        #endif
        }
    }

    var label: String {
        switch self {
        case .albums: String(localized: "Albums")
        case .artists: String(localized: "Artists")
        case .songs: String(localized: "Songs")
        case let .playlist(playlist): playlist.name

        #if os(iOS)
            case .playlists: String(localized: "Playlists")
        #endif
        }
    }

    var symbol: SFSymbol {
        switch self {
        case .albums: .squareStack
        case .artists: .musicMicrophone
        case .songs: .musicNote
        case .playlist: .musicNoteList

        #if os(iOS)
            case .playlists: .musicNoteList
        #endif
        }
    }
}

enum ContentDestination: Identifiable, Codable, Hashable {
    case album(Album)
    case artist(Artist)
}
