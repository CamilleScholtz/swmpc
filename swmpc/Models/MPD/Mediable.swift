//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 16/11/2024.
//

import SwiftUI

protocol Mediable: Identifiable, Equatable, Hashable, Sendable {
    var id: UInt32 { get }
    var position: UInt32 { get }
}

protocol Playable: Mediable {
    var url: URL { get }
}

struct Artist: Mediable {
    let id: UInt32
    let position: UInt32

    let name: String

    // TODO: I don't really like this...
    var albums: [Album]?
}

struct Album: Playable {
    let id: UInt32
    let position: UInt32
    let url: URL

    let artist: String
    let title: String
    let date: String
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

struct Playlist: Identifiable, Equatable, Hashable, Sendable {
    var id: String { name }

    let name: String
}
