//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

protocol Mediable: Identifiable, Hashable, Sendable {
    var id: UInt32 { get }
}

protocol Artworkable {
    var uri: URL { get }
}

struct Artist: Mediable {
    static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.id == rhs.id && lhs.albums?.count == rhs.albums?.count
    }

    let id: UInt32

    let name: String

    var albums: [Album]?

    mutating func set(albums: [Album]) {
        self.albums = albums
    }
}

struct Album: Mediable, Artworkable {
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id && lhs.songs?.count == rhs.songs?.count
    }

    let id: UInt32
    let uri: URL

    let artist: String
    let title: String
    let date: String

    var songs: [Int: [Song]]?

    var duration: Double? {
        songs?.values.flatMap(\.self).reduce(0) { $0 + $1.duration }
    }

    var tracks: Int? {
        songs?.values.reduce(0) { $0 + $1.count }
    }

    mutating func set(songs: [Song]) {
        self.songs = Dictionary(grouping: songs, by: { $0.disc })
    }
}

struct Song: Mediable, Artworkable {
    let id: UInt32
    let uri: URL

    let artist: String
    let title: String
    let duration: Double

    let disc: Int
    let track: Int

    var description: String {
        "\(artist) - \(title)"
    }
}

struct Playlist: Mediable {
    static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id && lhs.songs?.count == rhs.songs?.count
    }

    let id: UInt32

    let name: String

    var songs: [Int: [Song]]?

    var tracks: Int? {
        songs?.values.reduce(0) { $0 + $1.count }
    }

    mutating func set(songs: [Song]) {
        self.songs = Dictionary(grouping: songs, by: { $0.disc })
    }
}

