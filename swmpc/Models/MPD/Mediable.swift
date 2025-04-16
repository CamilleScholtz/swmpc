//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

protocol Mediable: Identifiable, Equatable, Hashable, Codable, Sendable {
    var id: UInt32 { get }
    var position: UInt32 { get }
}

extension Mediable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

protocol Playable: Mediable {
    var url: URL { get }
}

struct Artist: Mediable {
    let id: UInt32
    let position: UInt32

    let name: String

    // TODO: I don't really like this as it is not consisten with the other
    // structs, `Album` doesn't have [`Song`] for example. I haven't found
    // a more efficient way of doing this though.
    var albums: [Album]?
}

struct Album: Playable {
    let id: UInt32
    let position: UInt32
    let url: URL

    let artist: String
    let title: String
    let date: String

    var description: String {
        "\(artist) - \(title)"
    }
}

struct Song: Playable {
    let id: UInt32
    let position: UInt32
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
