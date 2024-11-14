//
//  Song.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct Song: Identifiable, Equatable, Sendable {
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }

    let id: URL

    let artist: String?
    let title: String?
    let duration: Double?

    var description: String {
        "\(artist ?? "Unknown artist") - \(title ?? "Unknown title")"
    }
}
