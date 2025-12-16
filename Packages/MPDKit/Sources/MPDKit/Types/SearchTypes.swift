//
//  SearchTypes.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

import SwiftUI

/// Represents individual search fields that can be selected.
public enum SearchField: String, CaseIterable, Sendable {
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
    public var label: LocalizedStringResource {
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
}

/// Manages the selected search fields for searching media.
public nonisolated struct SearchFields: Equatable, RawRepresentable, Sendable {
    private var selectedFields: Set<SearchField>

    /// The default search fields (empty set).
    public static let `default` = SearchFields()

    /// Initializes search fields with an optional set of pre-selected fields.
    /// - Parameter fields: The set of search fields to initially select.
    public init(fields: Set<SearchField> = []) {
        selectedFields = fields
    }

    /// Creates search fields from a string representation.
    /// - Parameter rawValue: Comma-separated list of search field raw values.
    public init(rawValue: String) {
        if rawValue.isEmpty {
            selectedFields = []
        } else {
            selectedFields = Set(
                rawValue.split(separator: ",")
                    .compactMap { SearchField(rawValue: String($0)) },
            )
        }
    }

    /// The string representation of selected fields for persistence.
    public var rawValue: String {
        selectedFields.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// Toggles the selection state of a search field.
    /// - Parameter field: The search field to toggle.
    public mutating func toggle(_ field: SearchField) {
        if selectedFields.contains(field) {
            selectedFields.remove(field)
        } else {
            selectedFields.insert(field)
        }
    }

    /// Checks if a specific search field is selected.
    /// - Parameter field: The search field to check.
    /// - Returns: `true` if the field is selected, `false` otherwise.
    public func contains(_ field: SearchField) -> Bool {
        selectedFields.contains(field)
    }

    /// Indicates whether no search fields are selected.
    public var isEmpty: Bool {
        selectedFields.isEmpty
    }

    /// Returns the selected fields as a set of lowercase string values for
    /// MPD queries.
    public var fields: Set<String> {
        Set(selectedFields.map { $0.rawValue.lowercased() })
    }
}
