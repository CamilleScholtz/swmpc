//
//  Album.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct Album: Identifiable, Sendable {
    let id: URL

    let artist: String?
    let title: String?
    let date: String?

    var songs: [Song] = []

    var description: String {
        "\(date ?? "Unknown date") - \(title ?? "Unknown title")"
    }
}
