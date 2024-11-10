//
//  Song.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct Song: Mediable, Identifiable, Equatable, Sendable {
    static func == (lhs: Song, rhs: Song) -> Bool {
        lhs.id == rhs.id
    }

    var id: String

    var artist: String?
    var title: String?
    var duration: Double?

    var description: String {
        "\(artist ?? "Unknown artist") - \(title ?? "Unknown title")"
    }
}
