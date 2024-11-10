//
//  Mediable.swift
//  swmpc
//
//  Created by Camille Scholtz on 10/11/2024.
//

protocol Mediable: Sendable {
    var id: String { get }
}

enum MediaType: String {
    case album = "Album"
    case artist = "Artist"
    case song = "Song"
}
