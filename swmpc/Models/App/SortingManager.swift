//
//  SortingManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/07/2025.
//

import SwiftUI

enum SortOption: String, CaseIterable, Codable {
    case artist
    case album
    case title
    case name

    var label: String {
        switch self {
        case .artist: "Artist"
        case .album: "Album"
        case .title: "Title"
        case .name: "Name"
        }
    }
}

enum SortDirection: String, CaseIterable, Codable {
    case ascending
    case descending

    var label: String {
        switch self {
        case .ascending: "Ascending"
        case .descending: "Descending"
        }
    }
}

struct SortDescriptor: Codable, Hashable {
    var option: SortOption
    var direction: SortDirection

    var label: String {
        option.label
    }

    var rawValue: String {
        "\(option.rawValue)_\(direction.rawValue)"
    }

    init(option: SortOption, direction: SortDirection = .ascending) {
        self.option = option
        self.direction = direction
    }

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

enum SortingManager {
    /// Sorts and optionally filters an array of media items.
    ///
    /// This function first filters the media array based on the `searchQuery`. If the query is empty,
    /// all items are kept. It then sorts the resulting array using the provided `sortDescriptor`.
    ///
    /// - Parameters:
    ///   - media: The array of `Mediable` items to be sorted and filtered.
    ///   - sortDescriptor: The `SortDescriptor` that defines the sorting key (e.g., artist, title) and direction (ascending, descending).
    ///   - searchQuery: An optional string to filter the media. The filter is case-insensitive and checks relevant properties of each media item.
    /// - Returns: A new array of `Mediable` items, filtered and sorted according to the specified criteria.
    static func sorted(
        _ media: [any Mediable],
        by sortDescriptor: SortDescriptor,
        searchQuery: String = "",
    ) async -> [any Mediable] {
        let filtered = filter(media, by: searchQuery)

        return await performSort(filtered, by: sortDescriptor)
    }

    /// Generates a list of available sort options for a specific media type.
    ///
    /// Different media types have different sortable properties. For example, an `Album` can be sorted by artist or title,
    /// while an `Artist` can only be sorted by name. This method provides all valid `SortOption`s for the given type.
    ///
    /// - Parameter mediaType: The `MediaType` (e.g., `.album`, `.song`) for which to get the available sort options.
    /// - Returns: An array of `SortOption`s that can be applied to a collection of the specified media type.
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

    /// Filters an array of media items based on a search query.
    ///
    /// The function performs a case-insensitive search. It checks different properties depending on the
    /// concrete type of the `Mediable` item (e.g., title and artist for a `Song`, name for an `Artist`).
    /// If the search query is empty, the original array is returned unmodified.
    ///
    /// - Parameters:
    ///   - media: The array of `Mediable` items to filter.
    ///   - searchQuery: The string to search for within the media items.
    /// - Returns: A new, filtered array of `Mediable` items that match the search query.
    private static func filter(_ media: [any Mediable], by searchQuery: String) -> [any Mediable] {
        guard !searchQuery.isEmpty else {
            return media
        }

        let lowercasedQuery = searchQuery.lowercased()

        return media.filter { mediable in
            switch mediable {
            case let song as Song:
                song.artist.lowercased().contains(lowercasedQuery) ||
                    song.title.lowercased().contains(lowercasedQuery)
            case let album as Album:
                album.title.lowercased().contains(lowercasedQuery) ||
                    album.artist.name.lowercased().contains(lowercasedQuery)
            case let artist as Artist:
                artist.name.lowercased().contains(lowercasedQuery)
            default:
                false
            }
        }
    }

    /// Sorts an array of media items using a specific sort descriptor.
    ///
    /// This function uses `localizedStandardCompare` for sorting, which provides natural sorting
    /// for strings containing numbers (e.g., "Song 2" comes before "Song 10").
    ///
    /// - Parameters:
    ///   - media: The array of `Mediable` items to sort.
    ///   - sortDescriptor: The `SortDescriptor` defining the sort key and direction.
    /// - Returns: A new, sorted array of `Mediable` items.
    private static func performSort(
        _ media: [any Mediable],
        by sortDescriptor: SortDescriptor,
    ) async -> [any Mediable] {
        media.sorted { lhs, rhs in
            let (lhsValue, rhsValue) = getSortValues(lhs, rhs, for: sortDescriptor.option)

            guard let lhsValue, let rhsValue else {
                return false
            }

            let comparison = lhsValue.localizedStandardCompare(rhsValue)

            return sortDescriptor.direction == .ascending
                ? comparison == .orderedAscending
                : comparison == .orderedDescending
        }
    }

    /// Extracts the string values to be used for comparison from two media items.
    ///
    /// Based on the `SortOption`, this helper function calls the appropriate getter (e.g., `getArtist`, `getAlbum`)
    /// to retrieve the comparable string properties from the left-hand side (lhs) and right-hand side (rhs) items.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand side `Mediable` item in the comparison.
    ///   - rhs: The right-hand side `Mediable` item in the comparison.
    ///   - option: The `SortOption` specifying which property to extract.
    /// - Returns: A tuple containing the optional string values from the `lhs` and `rhs` items, respectively.
    private nonisolated static func getSortValues(_ lhs: any Mediable, _ rhs: any Mediable, for option: SortOption) -> (String?, String?) {
        switch option {
        case .artist:
            (getArtist(from: lhs), getArtist(from: rhs))
        case .album:
            (getAlbum(from: lhs), getAlbum(from: rhs))
        case .title:
            (getTitle(from: lhs), getTitle(from: rhs))
        case .name:
            (getName(from: lhs), getName(from: rhs))
        }
    }

    /// Retrieves the artist name from a media item.
    ///
    /// This helper handles different `Mediable` types, extracting the artist name
    /// from a `Song`, `Album`, or `Artist` object.
    ///
    /// - Parameter item: The `Mediable` item from which to extract the artist name.
    /// - Returns: The artist name as a `String`, or `nil` if the item type doesn't have an artist property.
    private nonisolated static func getArtist(from item: any Mediable) -> String? {
        switch item {
        case let song as Song: song.artist
        case let album as Album: album.artist.name
        case let artist as Artist: artist.name
        default: nil
        }
    }

    /// Retrieves the album title from a media item.
    ///
    /// This helper handles different `Mediable` types, extracting the album title
    /// from a `Song` or `Album` object.
    ///
    /// - Parameter item: The `Mediable` item from which to extract the album title.
    /// - Returns: The album title as a `String`, or `nil` if the item type doesn't have an album property.
    private nonisolated static func getAlbum(from item: any Mediable) -> String? {
        switch item {
        case let song as Song: song.album.title
        case let album as Album: album.title
        default: nil
        }
    }

    /// Retrieves the title from a media item.
    ///
    /// This helper handles different `Mediable` types, extracting the title
    /// from a `Song` or `Album` object.
    ///
    /// - Parameter item: The `Mediable` item from which to extract the title.
    /// - Returns: The title as a `String`, or `nil` if the item type doesn't have a title property.
    private nonisolated static func getTitle(from item: any Mediable) -> String? {
        switch item {
        case let song as Song: song.title
        case let album as Album: album.title
        default: nil
        }
    }

    /// Retrieves the name from a media item.
    ///
    /// This helper is specifically designed to extract the name from an `Artist` object.
    ///
    /// - Parameter item: The `Mediable` item from which to extract the name.
    /// - Returns: The name as a `String` if the item is an `Artist`, otherwise `nil`.
    private nonisolated static func getName(from item: any Mediable) -> String? {
        switch item {
        case let artist as Artist: artist.name
        default: nil
        }
    }
}
