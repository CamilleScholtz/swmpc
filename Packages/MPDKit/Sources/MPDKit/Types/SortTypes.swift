//
//  SortTypes.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import SwiftUI

/// Represents a sort descriptor for media items.
public enum SortOption: String, Sendable {
    /// Sort by album artist.
    case artist = "albumartistsort"
    /// Sort by album title.
    case album = "albumsort"
    /// Sort by song title.
    case song = "titlesort"
    /// Sort by the last modified date.
    case modified = "Last-Modified"

    /// Returns the localized display label for this sort option.
    public var label: LocalizedStringResource {
        switch self {
        case .artist:
            "Artist"
        case .album:
            "Album"
        case .song:
            "Song"
        case .modified:
            "Last Modified"
        }
    }
}

/// Represents the direction of sorting for media items.
public enum SortDirection: String, Sendable {
    /// Sort in ascending order.
    case ascending = ""
    /// Sort in descending order.
    case descending = "-"

    /// Returns the localized display label for this sort direction.
    public var label: LocalizedStringResource {
        switch self {
        case .ascending:
            "Ascending"
        case .descending:
            "Descending"
        }
    }
}

/// Represents a complete sort descriptor combining a sort option with a
/// direction.
///
/// Used to specify how collections of media items should be sorted. The
/// descriptor can be serialized to and from a string representation for
/// persistence.
public nonisolated struct SortDescriptor: RawRepresentable, Equatable, Hashable,
    Sendable
{
    /// The field or property to sort by.
    public let option: SortOption

    /// The direction of the sort (ascending or descending).
    public let direction: SortDirection

    /// The default sort descriptor, sorting by artist in ascending order.
    public static let `default` = SortDescriptor(option: .artist, direction:
        .ascending)

    /// Creates a sort descriptor with the specified option and direction.
    ///
    /// - Parameters:
    ///   - option: The field to sort by.
    ///   - direction: The sort direction. Defaults to `.ascending`.
    public init(option: SortOption, direction: SortDirection = .ascending) {
        self.option = option
        self.direction = direction
    }

    /// Creates a sort descriptor from its string representation.
    ///
    /// The expected format is "option_direction" where direction is either
    /// "ascending" or "descending". If direction is omitted, defaults to
    /// ascending. Returns the default descriptor if parsing fails.
    ///
    /// - Parameter rawValue: The string representation of the sort descriptor.
    public init(rawValue: String) {
        let components = rawValue.split(separator: "_")
        guard let first = components.first,
              let option = SortOption(rawValue: String(first))
        else {
            self = .default

            return
        }

        self.option = option
        direction = components.count == 2 && components[1] == "descending" ?
            .descending : .ascending
    }

    /// The string representation of this sort descriptor.
    ///
    /// Returns a string in the format "option_direction" for serialization.
    public var rawValue: String {
        "\(option.rawValue)_\(direction == .ascending ? "ascending" : "descending")"
    }
}
