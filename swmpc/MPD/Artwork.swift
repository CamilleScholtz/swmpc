//
//  Artwork.swift
//  swmpc
//
//  Created by Camille Scholtz on 09/11/2024.
//

import SwiftUI

// TODO: Uhh?
extension NSImage: @unchecked @retroactive Sendable {}

@Observable class Artwork {
    var image: NSImage?

    @ObservationIgnored var uri: String?
    @ObservationIgnored var timestamp: TimeInterval?

    init(uri: String) {
        self.uri = uri
    }

    @MainActor
    func set(using commandManager: ConnectionManager) async {
        guard let uri else {
            return
        }

        image = await commandManager.getArtwork(for: uri)
        timestamp = Date().timeIntervalSince1970
    }
}
