//
//  Album.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

// TODO: Uhh?
extension NSImage: @unchecked @retroactive Sendable {}

struct Album: Identifiable, Equatable, Sendable {
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }
    
    var id: String

    var artist: String?
    var title: String?
    var year: String?

    var songs: [Song] = []

    var artwork: NSImage?
}
