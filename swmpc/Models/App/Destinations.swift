//
//  Destinations.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/03/2025.
//

import SFSafeSymbols
import SwiftUI

enum SidebarDestination: Identifiable, Codable, Hashable {
    case albums
    case artists
    case songs
    case playlist(Playlist)

    #if os(iOS)
        case playlists
        case settings
    #endif

    static var categories: [Self] {
        #if os(iOS)
            [.albums, .artists, .songs, .playlists, .settings]
        #elseif os(macOS)
            [.albums, .artists, .songs]
        #endif
    }

    var type: MediaType? {
        switch self {
        case .albums: .album
        case .artists: .artist
        case .songs: .song
        case .playlist: .playlist
        #if os(iOS)
            default: nil
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
            case .settings: String(localized: "Settings")
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
            case .settings: .gear
        #endif
        }
    }

    var shortcut: KeyboardShortcut? {
        switch self {
        case .albums: KeyboardShortcut("1", modifiers: [])
        case .artists: KeyboardShortcut("2", modifiers: [])
        case .songs: KeyboardShortcut("3", modifiers: [])
        default: nil
        }
    }
}

enum ContentDestination: Identifiable, Codable, Hashable {
    case album(Album)
    case artist(Artist)
}
