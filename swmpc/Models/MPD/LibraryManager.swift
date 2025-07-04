//
//  LibraryManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

enum LibraryManagerError: Error {
    case invalidType
}

/// Manages the MPD library (a database or queue), handling media storage and
/// search functionality.
@Observable
final class LibraryManager {
    /// The source `LibraryManager` is managing. This can be either `.database`
    /// or `.queue`.
    var source: Source

    /// Initializes a new `LibraryManager` with the specified source.
    ///
    /// - Parameter source: The source to manage, either `.database` or
    ///                     `.queue`.
    init(using source: Source) {
        self.source = source
    }

    /// The media in the library. This represents the actual contents.
    private(set) var internalMedia: [any Mediable] = []

    /// The media in the library. This can be the actual contents (see
    /// `internalMedia`) or the filtered search results.
    private(set) var media: [any Mediable] {
        get {
            results ?? internalMedia
        }
        set {
            internalMedia = newValue
        }
    }

    /// The search results. If this value is not `nil`, `media` will return
    /// this.
    private(set) var results: [any Mediable]?

    /// The type of media in the library. This can be `album`, `artist` or
    /// `song`.
    private(set) var type: MediaType?

    /// The date at which the library was last updated.
    private(set) var lastUpdated: Date = .now

    /// This asynchronous function sets the media in library.
    ///
    /// - Parameters:
    ///     - type: The type of media to set.
    ///     - idle: Whether to use the idle connection.
    ///     - force: Whether to force the update, this will update the database
    ///              even if the type is the same as the current one.
    /// - Throws: An error if the media could not be set.
    @MainActor
    func set(using type: MediaType? = nil, idle: Bool = false, force: Bool =
        false) async throws
    {
        defer { lastUpdated = Date() }

        let targetType = type ?? self.type
        guard force || targetType != self.type else {
            return
        }

        defer {
            self.type = targetType
        }

        switch targetType {
        case .album:
            media = try await idle
                ? ConnectionManager.idle.getAlbums(from: source)
                : ConnectionManager.command().getAlbums(from: source)
        case .artist:
            media = try await idle
                ? ConnectionManager.idle.getArtists(from: source)
                : ConnectionManager.command().getArtists(from: source)
        case .song:
            media = try await idle
                ? ConnectionManager.idle.getSongs(from: source)
                : ConnectionManager.command().getSongs(from: source)
        default:
            throw LibraryManagerError.invalidType
        }
    }

    /// This asynchronous function searches for media in the library.
    ///
    /// - Parameters:
    ///     - query: The query to search for.
    ///     - type: The type of media to search for and set.
    /// - Throws: An error if the search could not be performed.
    @MainActor
    func search(for query: String, using type: MediaType? = nil) async throws {
        let targetType = type ?? self.type
        try await set(using: targetType)

        results = switch targetType {
        case .album:
            (internalMedia as! [Album]).filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        case .artist:
            (internalMedia as! [Artist]).filter {
                $0.name.range(of: query, options: .caseInsensitive) != nil
            }
        case .song:
            (internalMedia as! [Song]).filter {
                $0.artist.range(of: query, options: .caseInsensitive) != nil ||
                    $0.title.range(of: query, options: .caseInsensitive) != nil
            }
        default:
            throw LibraryManagerError.invalidType
        }
    }

    /// Clears the search results, resetting the media to the internal media.
    func clearResults() {
        results = nil
    }
}
