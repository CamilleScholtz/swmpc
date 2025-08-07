//
//  NavigationManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/04/2025.
//

import SFSafeSymbols
import SwiftUI

/// Manages navigation state for the application, handling both category-level
/// navigation and content navigation within those categories.
///
/// This class uses SwiftUI's `NavigationPath` to maintain a navigation stack
/// while also tracking the current category selection. When the category
/// changes, the navigation path is automatically reset to provide a clean
/// navigation state.
@Observable final class NavigationManager {
    /// The navigation path representing the current navigation stack within the
    /// selected category. This stack contains `ContentDestination` values that
    /// represent navigation to specific albums or artists.
    var path = NavigationPath()

    /// The currently selected category destination (e.g., albums, artists,
    /// songs, playlists). When this value changes, the navigation path is
    /// automatically reset to ensure a clean navigation state for the new
    /// category.
    var category: CategoryDestination = .albums {
        didSet {
            if oldValue != category {
                reset()
            }
        }
    }

    /// Navigates to a specific content destination by appending it to the
    /// navigation path.
    /// - Parameter content: The content destination to navigate to (album or
    ///                      artist).
    func navigate(to content: ContentDestination) {
        path.append(content)
    }

    /// Removes the last item from the navigation path, effectively going back
    /// one level. If the path is already empty, this method does nothing.
    func goBack() {
        guard !path.isEmpty else {
            return
        }

        path.removeLast()
    }

    /// Resets the navigation path to an empty state, returning to the root of
    /// the current category.
    func reset() {
        path = NavigationPath()
    }
}

/// Represents the different category destinations available in the app's
/// navigation.
///
/// Categories are the top-level navigation items that organize the music
/// library. On iOS, this includes additional categories like playlists and
/// settings that are accessed through the tab bar.
enum CategoryDestination: Identifiable, Codable, Hashable {
    /// Returns self as the stable identity for `Identifiable` conformance.
    var id: Self { self }

    /// The albums view showing all albums in the library.
    case albums
    /// The artists view showing all artists in the library.
    case artists
    /// The songs view showing all songs in the library.
    case songs
    /// A specific playlist view showing the contents of the given playlist.
    case playlist(Playlist)

    #if os(iOS)
        /// The playlists view showing all available playlists (iOS only).
        case playlists
        /// The settings view for app configuration (iOS only).
        case settings
    #endif

    /// Returns the available category destinations for the current platform.
    /// - iOS: Returns albums, artists, songs, and playlists
    /// - macOS: Returns albums, artists, and songs
    static var categories: [Self] {
        #if os(iOS)
            [.albums, .artists, .songs, .playlists]
        #elseif os(macOS)
            [.albums, .artists, .songs]
        #endif
    }

    /// The media type associated with this category destination.
    /// Used to determine how to display and interact with the content.
    var type: MediaType {
        switch self {
        case .albums: .album
        case .artists: .artist
        case .songs: .song
        case .playlist: .playlist
        #if os(iOS)
            case .playlists: .playlist
            case .settings: .song
        #endif
        }
    }

    /// The source of content for this category destination.
    /// Determines where the data comes from (database, playlist, or favorites).
    var source: Source {
        switch self {
        case .albums, .artists, .songs:
            .database
        case let .playlist(playlist):
            playlist.name == "Favorites" ? .favorites : .playlist(playlist)
        #if os(iOS)
            case .playlists:
                .database
            case .settings:
                .database
        #endif
        }
    }

    /// The localized display label for this category destination.
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

    /// The SF Symbol associated with this category destination for display in the UI.
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

    /// The keyboard shortcut for quickly navigating to this category.
    ///
    /// - Returns: A keyboard shortcut for albums (1), artists (2), and songs
    ///            (3), or nil for other categories.
    @available(macOS 26.0, *)
    var shortcut: KeyboardShortcut? {
        switch self {
        case .albums: KeyboardShortcut("1", modifiers: [])
        case .artists: KeyboardShortcut("2", modifiers: [])
        case .songs: KeyboardShortcut("3", modifiers: [])
        default: nil
        }
    }
}

/// Represents specific content destinations within a category.
///
/// These are the detail views that users navigate to from the category lists,
/// such as viewing a specific album's songs or an artist's albums.
enum ContentDestination: Identifiable, Hashable {
    /// Returns self as the stable identity for `Identifiable` conformance.
    var id: Self { self }

    /// Navigation to a specific album's detail view.
    case album(Album)
    /// Navigation to a specific artist's detail view.
    case artist(Artist)
}
