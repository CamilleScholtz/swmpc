//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

protocol Mediable: Identifiable, Sendable {
    var id: UInt32 { get }
    var uri: URL { get }
}

struct Artist: Mediable {
    let id: UInt32
    let uri: URL

    let name: String

    var albums: [Album] = []
    
    mutating func add(albums: [Album]) {
        self.albums.append(contentsOf: albums)
    }
}

struct Album: Mediable {
    let id: UInt32
    let uri: URL

    let artist: String?
    let title: String?
    let date: String?

    var songs: [Song] = []

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

struct Song: Mediable, Equatable {
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }

    let id: UInt32
    let uri: URL

    let artist: String?
    let track: String?
    let title: String?
    let duration: Double?

    var description: String {
        "\(artist ?? "Unknown artist") - \(title ?? "Unknown title")"
    }
}
