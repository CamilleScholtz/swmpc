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
    let id: UInt32

    let name: String

    // TODO: I don't really like this...
    var albums: [Album]?
}

struct Album: Mediable, Artworkable {
    let id: UInt32
    let uri: URL

    let artist: String
    let title: String
    let date: String
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
    let id: UInt32

    let name: String
}
