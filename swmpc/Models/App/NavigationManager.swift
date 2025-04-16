//
//  NavigationManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/04/2025.
//

import SFSafeSymbols
import SwiftUI

// TODO: `content` and `path` feel a duplicate, but I really cant figure out how
// to get the "contents" of the `path`.
@Observable
final class NavigationManager {
    var path = NavigationPath()

    var category: CategoryDestination = .albums {
        didSet {
            if oldValue != category {
                reset()
            }
        }
    }

    var content: [ContentDestination] = []

    func navigate(to content: ContentDestination) {
        guard content != self.content.last else {
            return
        }

        if self.content.contains(content) {
            while self.content.last != content {
                goBack()
            }
        } else {
            path.append(content)
            self.content.append(content)
        }
    }

    func goBack() {
        guard !path.isEmpty else {
            return
        }

        path.removeLast()
        content.removeLast()
    }

    func reset() {
        path = NavigationPath()
        content = []
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
    var id: Self { self }

    case album(Album)
    case artist(Artist)
}
