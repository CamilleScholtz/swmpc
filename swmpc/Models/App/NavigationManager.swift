//
//  NavigationManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 07/04/2025.
//

import MPDKit
import SFSafeSymbols
import SwiftUI

/// Manages navigation state for the application, handling both category-level
/// navigation and content navigation within those categories.
///
/// This class maintains a SwiftUI `NavigationPath` per category, so each
/// category keeps its own navigation stack: switching categories preserves
/// where the user was, and re-selecting the current category pops its stack
/// back to the root.
@Observable final class NavigationManager {
    /// The navigation paths per category. Each stack contains
    /// `ContentDestination` values that represent navigation to specific
    /// albums or artists.
    private var paths: [CategoryDestination: NavigationPath] = [:]

    /// Two-way access to a specific category's navigation path, usable as a
    /// key path binding (`$navigator[path: category]`) so each tab owns its
    /// own stack.
    subscript(path category: CategoryDestination) -> NavigationPath {
        get {
            paths[category] ?? NavigationPath()
        }
        set {
            paths[category] = newValue
            syncPathContents(for: category)
        }
    }

    /// The navigation path of the currently selected category.
    var path: NavigationPath {
        get {
            self[path: category]
        }
        set {
            self[path: category] = newValue
        }
    }

    /// The currently selected category destination (e.g., albums, artists,
    /// songs, playlists). Re-selecting the already-current category (tapping
    /// the active tab, or clicking the active sidebar row) pops its
    /// navigation stack back to the root.
    var category: CategoryDestination = .albums {
        didSet {
            if oldValue == category {
                popToRoot()
            }
        }
    }

    #if os(iOS)
        /// Controls the presentation of the settings sheet on iOS.
        var showSettingsSheet = false

        /// Controls the presentation of the now playing view on iOS.
        var showNowPlaying = false
    #endif

    /// The target for the intelligence sheet (queue or playlist); drives its
    /// presentation when non-nil.
    var intelligenceTarget: IntelligenceTarget?

    /// Controls the presentation of the clear queue alert.
    var showClearQueueAlert = false

    /// Controls the presentation of the ratings sheet.
    var showRatingsSheet = false

    /// Tracks the content destinations in each category's path for duplicate
    /// prevention. This is internal state that doesn't need to trigger view
    /// updates.
    @ObservationIgnored private var pathContents: [CategoryDestination: [ContentDestination]] = [:]

    /// Scroll offsets the user manually scrolled to, per category, measured
    /// from the top of the content. A present entry means the category
    /// restores its browsed position instead of focusing the currently
    /// playing media. This is internal state that doesn't need to trigger
    /// view updates.
    @ObservationIgnored private var scrollOffsets: [CategoryDestination: CGFloat] = [:]

    /// Records the scroll offset the user scrolled to in a category.
    /// - Parameters:
    ///   - offset: The scroll offset, measured from the top of the content.
    ///   - category: The category the offset belongs to.
    func recordScrollOffset(_ offset: CGFloat, for category: CategoryDestination) {
        scrollOffsets[category] = offset
    }

    /// The scroll offset to restore for a category.
    /// - Parameter category: The category to restore the offset for.
    /// - Returns: The remembered offset, or `nil` when the user hasn't
    ///            manually scrolled the category and its list should focus
    ///            the currently playing media instead.
    func scrollOffset(for category: CategoryDestination) -> CGFloat? {
        scrollOffsets[category]
    }

    /// Clears the remembered scroll offset for a category, re-enabling
    /// focusing of the currently playing media.
    /// - Parameter category: The category to clear the offset for.
    func clearScrollOffset(for category: CategoryDestination) {
        scrollOffsets[category] = nil
    }

    /// Navigates to a specific content destination by appending it to the
    /// current category's navigation path.
    /// - Parameter content: The content destination to navigate to (album or
    ///                      artist).
    func navigate(to content: ContentDestination) {
        if let last = pathContents[category]?.last, last == content {
            return
        }

        path.append(content)
        pathContents[category, default: []].append(content)
    }

    /// Removes the last item from the current category's navigation path,
    /// effectively going back one level. If the path is already empty, this
    /// method does nothing.
    func goBack() {
        guard !path.isEmpty else {
            return
        }

        path.removeLast()
    }

    /// Pops the current category's navigation path back to its root.
    func popToRoot() {
        path = NavigationPath()
    }

    /// Synchronizes a category's tracked content destinations with its actual
    /// `NavigationPath` count. This ensures the tracking stays in sync when
    /// SwiftUI modifies the path directly (e.g., via the back button).
    private func syncPathContents(for category: CategoryDestination) {
        let currentCount = paths[category]?.count ?? 0
        let tracked = pathContents[category] ?? []

        if currentCount < tracked.count {
            pathContents[category] = Array(tracked.prefix(currentCount))
        }
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
    var id: Self {
        self
    }

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
        #endif
        }
    }

    /// The localized display label for this category destination.
    var label: LocalizedStringResource {
        switch self {
        case .albums: "Albums"
        case .artists: "Artists"
        case .songs: "Songs"
        case let .playlist(playlist): LocalizedStringResource(stringLiteral:
                playlist.name)
        #if os(iOS)
            case .playlists: "Playlists"
        #endif
        }
    }

    /// The SF Symbol associated with this category destination for display in
    /// the UI.
    var symbol: SFSymbol {
        switch self {
        case .albums: .squareStack
        case .artists: .musicMicrophone
        case .songs: .musicNote
        case let .playlist(playlist): playlist.symbol
        #if os(iOS)
            case .playlists: .musicNoteList
        #endif
        }
    }

    /// The keyboard shortcut for quickly navigating to this category.
    ///
    /// - Returns: A keyboard shortcut for albums (1), artists (2), and songs
    ///            (3), or nil for other categories.
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
    var id: Self {
        self
    }

    /// Navigation to a specific album's detail view.
    case album(Album)
    /// Navigation to a specific artist's detail view.
    case artist(Artist)
    #if os(iOS)
        /// Navigation to a specific playlist's detail view.
        case playlist(Playlist)
    #endif
}
