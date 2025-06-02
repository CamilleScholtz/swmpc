//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

protocol Mediable: Identifiable, Equatable, Hashable, Codable, Sendable {
    var identifier: UInt32? { get }
    var position: UInt32? { get }
    var url: URL { get }
}

extension Mediable {
    var id: URL { url }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    @MainActor
    func artwork() async throws -> PlatformImage? {
        let data = try await ArtworkManager.shared.get(for: self, shouldCache: !(self is Song))
        return PlatformImage(data: data)
    }
}

struct Artist: Mediable {
    let identifier: UInt32?
    let position: UInt32?
    let url: URL

    let name: String

    // TODO: I don't really like this as it is not consisten with the other
    // structs, `Album` doesn't have [`Song`] for example. I haven't found
    // a more efficient way of doing this though.
    var albums: [Album]?
}

struct Album: Mediable {
    let identifier: UInt32?
    let position: UInt32?
    let url: URL

    let artist: String
    let title: String
    let date: String

    var description: String {
        "\(artist) - \(title)"
    }
}

struct Song: Mediable {
    let identifier: UInt32?
    let position: UInt32?
    let url: URL

    let artist: String
    let title: String
    let duration: Double

    let disc: Int
    let track: Int

    var description: String {
        "\(artist) - \(title)"
    }
}

struct Playlist: Identifiable, Equatable, Hashable, Codable, Sendable {
    var id: String { name }

    let name: String
}
