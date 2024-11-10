//
//  Album.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct Album: Mediable, Identifiable, Sendable {
    var id: String

    var artist: String?
    var title: String?
    var date: String?

    var songs: [Song] = []

    var description: String {
        "\(date ?? "Unknown date") - \(title ?? "Unknown title")"
    }
}
