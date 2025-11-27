//
//  ListManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 10/11/2024.
//

import SFSafeSymbols
import SwiftUI

/// Represents a complete sort descriptor combining a sort option with a
/// direction.
///
/// Used to specify how collections of media items should be sorted. The
/// descriptor can be serialized to and from a string representation for
/// persistence.
nonisolated struct SortDescriptor: RawRepresentable, Equatable, Hashable {
    /// The field or property to sort by.
    let option: SortOption

    /// The direction of the sort (ascending or descending).
    let direction: SortDirection

    /// The default sort descriptor, sorting by artist in ascending order.
    static let `default` = SortDescriptor(option: .artist, direction:
        .ascending)

    /// Creates a sort descriptor with the specified option and direction.
    ///
    /// - Parameters:
    ///   - option: The field to sort by.
    ///   - direction: The sort direction. Defaults to `.ascending`.
    init(option: SortOption, direction: SortDirection = .ascending) {
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
    init(rawValue: String) {
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
    var rawValue: String {
        "\(option.rawValue)_\(direction == .ascending ? "ascending" :
            "descending")"
    }
}

/// Represents individual search fields that can be selected.
enum SearchField: String, CaseIterable {
    case title = "Title"
    case artist = "Artist"
    case album = "Album"
    case genre = "Genre"
    case composer = "Composer"
    case performer = "Performer"
    case conductor = "Conductor"
    case ensemble = "Ensemble"
    case mood = "Mood"
    case comment = "Comment"

    /// Returns the localized display label for this search field.
    var label: LocalizedStringResource {
        switch self {
        case .title:
            "Title"
        case .artist:
            "Artist"
        case .album:
            "Album"
        case .genre:
            "Genre"
        case .composer:
            "Composer"
        case .performer:
            "Performer"
        case .conductor:
            "Conductor"
        case .ensemble:
            "Ensemble"
        case .mood:
            "Mood"
        case .comment:
            "Comment"
        }
    }

    /// Returns the SF Symbol icon associated with this search field.
    var symbol: SFSymbol {
        switch self {
        case .title:
            .textformatCharacters
        case .artist:
            .person
        case .album:
            .squareStack
        case .genre:
            .musicNote
        case .composer:
            .musicNoteList
        case .performer:
            .musicMicrophone
        case .conductor:
            .wandAndSparkles
        case .ensemble:
            .person2
        case .mood:
            .faceSmiling
        case .comment:
            .textBubble
        }
    }
}

/// Manages the selected search fields for searching media.
nonisolated struct SearchFields: Equatable, RawRepresentable, Sendable {
    private var selectedFields: Set<SearchField>

    /// The default search fields (empty set).
    static let `default` = SearchFields()

    /// Initializes search fields with an optional set of pre-selected fields.
    /// - Parameter fields: The set of search fields to initially select.
    init(fields: Set<SearchField> = []) {
        selectedFields = fields
    }

    /// Creates search fields from a string representation.
    /// - Parameter rawValue: Comma-separated list of search field raw values.
    init(rawValue: String) {
        if rawValue.isEmpty {
            selectedFields = []
        } else {
            selectedFields = Set(
                rawValue.split(separator: ",")
                    .compactMap { SearchField(rawValue: String($0)) }
            )
        }
    }

    /// The string representation of selected fields for persistence.
    var rawValue: String {
        selectedFields.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// Toggles the selection state of a search field.
    /// - Parameter field: The search field to toggle.
    mutating func toggle(_ field: SearchField) {
        if selectedFields.contains(field) {
            selectedFields.remove(field)
        } else {
            selectedFields.insert(field)
        }
    }

    /// Checks if a specific search field is selected.
    /// - Parameter field: The search field to check.
    /// - Returns: `true` if the field is selected, `false` otherwise.
    func contains(_ field: SearchField) -> Bool {
        selectedFields.contains(field)
    }

    /// Indicates whether no search fields are selected.
    var isEmpty: Bool {
        selectedFields.isEmpty
    }

    /// Returns the selected fields as a set of lowercase string values for
    /// MPD queries.
    var fields: Set<String> {
        Set(selectedFields.map { $0.rawValue.lowercased() })
    }
}
