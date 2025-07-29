//
//  NavigationManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/04/2025.
//

import SFSafeSymbols
import SwiftUI

@Observable final class NavigationManager {
    var path = NavigationPath()

    var category: CategoryDestination = .albums {
        didSet {
            if oldValue != category {
                reset()
            } else {
                #if os(iOS)
                    NotificationCenter.default.post(name: .scrollToCurrentNotification, object: true)
                #endif
            }
        }
    }

    func navigate(to content: ContentDestination) {
        path.append(content)
    }

    func goBack() {
        guard !path.isEmpty else {
            return
        }

        path.removeLast()
    }

    func reset() {
        path = NavigationPath()
    }
}

enum CategoryDestination: Identifiable, Codable, Hashable {
    var id: Self { self }

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
        }
    }
    
    var source: Source {
        switch self {
        case .albums, .artists, .songs:
            .database
        case let .playlist(playlist):
            playlist.name == "Favorites" ? .favorites : .playlist(playlist)
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .albums: "Albums"
        case .artists: "Artists"
        case .songs: "Songs"
        case let .playlist(playlist): LocalizedStringResource(stringLiteral: playlist.name)

        #if os(iOS)
            case .playlists: "Playlists"
            case .settings: "Settings"
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

enum ContentDestination: Identifiable, Hashable {
    var id: Self { self }

    case album(Album)
    case artist(Artist)
}
