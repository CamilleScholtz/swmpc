//
//  Mediable.swift
//  MPDKit
//
//  Created by Camille Scholtz on 20/06/2025.
//

/// A protocol that defines the base requirements for all media items in the MPD
/// system.
///
/// Types conforming to `Mediable` represent various media entities (artists,
/// albums, songs) that can be stored, compared, and transmitted safely across
/// actor boundaries.
public protocol Mediable: Identifiable, Equatable, Codable, Hashable, Sendable {
    /// Returns a unique identifier for the media item.
    nonisolated var id: String { get }

    /// The file path of the media item in the MPD database.
    var file: String { get }
}

public extension Mediable {
    /// Checks if two media items are equal based on their identifiers.
    ///
    /// - Parameters:
    ///   - lhs: The first media item.
    ///   - rhs: The second media item.
    /// - Returns: `true` if the identifiers match, `false` otherwise.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    /// Generates a hash value for the media item based on its identifier.
    ///
    /// - Parameter hasher: The hasher to use for generating the hash value.
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
