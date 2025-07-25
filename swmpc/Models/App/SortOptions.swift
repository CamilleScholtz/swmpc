//
//  SortOptions.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

enum SortField: String, CaseIterable, Codable {
    case title
    case artist
    case album
    case name

    var label: String {
        switch self {
        case .title: "Title"
        case .artist: "Artist"
        case .album: "Album"
        case .name: "Name"
        }
    }
}

enum SortDirection: String, CaseIterable, Codable {
    case ascending
    case descending

    var label: String {
        switch self {
        case .ascending: "(A-Z)"
        case .descending: "(Z-A)"
        }
    }
}

struct SortOption: Hashable, Codable, Equatable {
    let field: SortField
    let direction: SortDirection

    var label: String {
        "\(field.label) \(direction.label)"
    }

    var rawValue: String {
        "\(field.rawValue)_\(direction.rawValue)"
    }

    init(field: SortField, direction: SortDirection) {
        self.field = field
        self.direction = direction
    }

    init?(rawValue: String) {
        let components = rawValue.split(separator: "_")

        guard components.count == 2,
              let field = SortField(rawValue: String(components[0])),
              let direction = SortDirection(rawValue: String(components[1]))
        else {
            return nil
        }

        self.field = field
        self.direction = direction
    }
}

extension MediaType {
    var availableSortFields: [SortField] {
        switch self {
        case .album:
            [.title, .artist]
        case .artist:
            [.name]
        case .song:
            [.title, .artist, .album]
        case .playlist:
            []
        }
    }

    var defaultSortOption: SortOption {
        switch self {
        case .album:
            SortOption(field: .artist, direction: .ascending)
        case .artist:
            SortOption(field: .name, direction: .ascending)
        case .song:
            SortOption(field: .album, direction: .ascending)
        case .playlist:
            SortOption(field: .title, direction: .ascending)
        }
    }
}
