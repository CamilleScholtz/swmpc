//
//  SortingManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/07/2025.
//

import SwiftUI

/// Defines the properties by which media items can be sorted.
nonisolated enum SortOption: String, CaseIterable, Codable {
    case artist
    case album
    case title
    case name

    /// A user-facing label for the sort option.
    var label: String {
        switch self {
        case .artist: "Artist"
        case .album: "Album"
        case .title: "Title"
        case .name: "Name"
        }
    }
}

/// Defines the direction of a sort operation.
nonisolated enum SortDirection: String, CaseIterable, Codable {
    /// Sorts items in ascending order (e.g., A-Z, 0-9).
    case ascending
    /// Sorts items in descending order (e.g., Z-A, 9-0).
    case descending

    /// A user-facing label for the sort direction.
    var label: String {
        switch self {
        case .ascending: "Ascending"
        case .descending: "Descending"
        }
    }
}

/// A structure that combines a sort option and a direction to describe how a
/// collection should be sorted.
///
/// This descriptor is `Codable` and can be initialized from a raw string
/// representation (e.g., "artist_ascending"), making it easy to store in
/// user defaults or other persistent storage.
nonisolated struct SortDescriptor: Codable, Hashable {
    /// The property to sort by (e.g., `.artist`, `.album`).
    var option: SortOption

    /// The direction of the sort (e.g., `.ascending`).
    var direction: SortDirection

    /// A user-facing label for the sort descriptor's option.
    var label: String {
        option.label
    }

    /// A string representation of the descriptor, combining option and
    /// direction.
    var rawValue: String {
        "\(option.rawValue)_\(direction.rawValue)"
    }

    /// Creates a new sort descriptor.
    ///
    /// - Parameters:
    ///   - option: The property to sort by.
    ///   - direction: The direction of the sort. Defaults to `.ascending`.
    init(option: SortOption, direction: SortDirection = .ascending) {
        self.option = option
        self.direction = direction
    }

    /// Creates a sort descriptor from a raw string value.
    ///
    /// - Parameter rawValue: A string in the format "option_direction"
    ///   (e.g., "artist_ascending").
    init?(rawValue: String) {
        let components = rawValue.split(separator: "_")
        guard components.count == 2,
              let option = SortOption(rawValue: String(components[0])),
              let direction = SortDirection(rawValue: String(components[1]))
        else {
            return nil
        }

        self.option = option
        self.direction = direction
    }
}

/// A namespace for static methods that handle filtering and sorting of media
/// items.
///
/// The manager provides a centralized way to apply consistent sorting logic
/// across the application. It includes optimizations to avoid re-sorting when
/// the requested order matches the natural order provided by the MPD server.
enum SortingManager {
    // Default sorts that match MPD's natural order
    nonisolated static let defaultAlbumSort = SortDescriptor(option: .artist, direction: .ascending)
    nonisolated static let defaultArtistSort = SortDescriptor(option: .name, direction: .ascending)
    nonisolated static let defaultSongSort = SortDescriptor(option: .album, direction: .ascending)

    /// Filters and sorts an array of media items.
    ///
    /// This function first filters the array based on the `searchQuery`. Then,
    /// it sorts the filtered results according to the provided
    /// `sortDescriptor`.
    ///
    /// An optimization is included: if the `mediaType` is provided and the
    /// `sortDescriptor` matches the default sort order for that type, the
    /// expensive sorting step is skipped, and the filtered array is returned
    /// directly.
    ///
    /// - Parameters:
    ///   - media: The array of `Mediable` items to process.
    ///   - sortDescriptor: The `SortDescriptor` that defines the sorting order.
    ///   - searchQuery: A string to filter items by. If empty, no filtering is
    ///                  applied. The search is case-insensitive.
    ///   - mediaType: The type of media being sorted, used for optimization.
    /// - Returns: A new array of `Mediable` items, filtered and sorted as
    ///            specified.
    @concurrent
    nonisolated static func sorted(
        _ media: [any Mediable],
        by sortDescriptor: SortDescriptor,
        searchQuery: String = "",
        mediaType: MediaType? = nil
    ) async -> [any Mediable] {
        // Filter first if needed
        let filtered = searchQuery.isEmpty ? media : media.filter { item in
            let query = searchQuery.lowercased()
            switch item {
            case let song as Song:
                return song.artist.lowercased().contains(query) ||
                    song.title.lowercased().contains(query)
            case let album as Album:
                return album.title.lowercased().contains(query) ||
                    album.artist.name.lowercased().contains(query)
            case let artist as Artist:
                return artist.name.lowercased().contains(query)
            default:
                return false
            }
        }

        if let mediaType = mediaType {
            let isDefaultSort = switch mediaType {
            case .album: sortDescriptor == defaultAlbumSort
            case .artist: sortDescriptor == defaultArtistSort
            case .song: sortDescriptor == defaultSongSort
            case .playlist: true // Playlists don't sort
            }

            if isDefaultSort {
                return filtered
            }
        }

        return filtered.sorted { lhs, rhs in
            let lhsValue: String?
            let rhsValue: String?

            switch sortDescriptor.option {
            case .artist:
                lhsValue = (lhs as? Song)?.artist ?? (lhs as? Album)?.artist.name ?? (lhs as? Artist)?.name
                rhsValue = (rhs as? Song)?.artist ?? (rhs as? Album)?.artist.name ?? (rhs as? Artist)?.name
            case .album:
                lhsValue = (lhs as? Song)?.album.title ?? (lhs as? Album)?.title
                rhsValue = (rhs as? Song)?.album.title ?? (rhs as? Album)?.title
            case .title:
                lhsValue = (lhs as? Song)?.title ?? (lhs as? Album)?.title
                rhsValue = (rhs as? Song)?.title ?? (rhs as? Album)?.title
            case .name:
                lhsValue = (lhs as? Artist)?.name
                rhsValue = (rhs as? Artist)?.name
            }

            guard let lhs = lhsValue, let rhs = rhsValue else { return false }

            let comparison = lhs.localizedStandardCompare(rhs)
            return sortDescriptor.direction == .ascending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }
    }

    /// Returns the available sort options for a given media type.
    ///
    /// Use this to populate UI elements, ensuring that only relevant sorting
    /// options are presented to the user for a specific context (e.g.,
    /// albums, songs).
    ///
    /// - Parameter mediaType: The type of media (e.g., `.album`, `.song`).
    /// - Returns: An array of `SortOption` values applicable to that media
    ///            type.
    static func availableSortOptions(for mediaType: MediaType) -> [SortOption] {
        switch mediaType {
        case .album:
            [.artist, .title]
        case .artist:
            [.name]
        case .song:
            [.album, .title, .artist]
        case .playlist:
            []
        }
    }
}
