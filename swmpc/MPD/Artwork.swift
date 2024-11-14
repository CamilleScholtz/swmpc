//
//  Artwork.swift
//  swmpc
//
//  Created by Camille Scholtz on 09/11/2024.
//

import SwiftUI

// TODO: Uhh?
extension NSImage: @unchecked @retroactive Sendable {}

@Observable class Artwork: Equatable {
    static func == (lhs: Artwork, rhs: Artwork) -> Bool {
        lhs.uri == rhs.uri
    }

    var image: NSImage?

    private var uri: URL?

    init(uri: URL) {
        self.uri = uri
    }

    @MainActor
    func set(using commandManager: ConnectionManager) async {
        guard let uri else {
            return
        }

        image = await commandManager.getArtwork(for: uri)
    }
}
