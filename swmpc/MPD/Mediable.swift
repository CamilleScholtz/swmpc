//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

protocol Mediable: Identifiable, Hashable, Sendable {
    var id: UInt32 { get }
    var uri: URL { get }
    var artworkUri: URL { get }
}

struct Artist: Mediable {
    static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.id == rhs.id && lhs.albums.count == rhs.albums.count
    }

    let id: UInt32
    let artworkUri: URL

    let name: String

    var albums: [Album] = []

    var uri: URL {
        artworkUri.deletingLastPathComponent().deletingLastPathComponent()
    }

    mutating func add(albums: [Album]) {
        self.albums.append(contentsOf: albums)
    }
}

struct Album: Mediable {
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id && lhs.songs.count == rhs.songs.count
    }

    let id: UInt32
    let artworkUri: URL

    let artist: String?
    let title: String?
    let date: String?

    var songs: [Song] = []

    var uri: URL {
        artworkUri.deletingLastPathComponent()
    }

    var artistUri: URL {
        artworkUri.deletingLastPathComponent().deletingLastPathComponent()
    }

    var description: String {
        "\(date ?? "Unknown date") - \(title ?? "Unknown title")"
    }

    var duration: Double? {
        songs.reduce(0) { $0 + ($1.duration ?? 0) }
    }

    mutating func add(songs: [Song]) {
        self.songs.append(contentsOf: songs)
    }
}

struct Song: Mediable {
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }

    let id: UInt32
    let uri: URL

    let artist: String?
    let track: String?
    let title: String?
    let duration: Double?

    var artworkUri: URL {
        uri
    }

    var albumUri: URL {
        uri.deletingLastPathComponent()
    }

    var artistUri: URL {
        uri.deletingLastPathComponent().deletingLastPathComponent()
    }

    var description: String {
        "\(artist ?? "Unknown artist") - \(title ?? "Unknown title")"
    }
}
