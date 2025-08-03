//
//  ScrollManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 31/07/2025.
//

import Foundation

enum ScrollManager {
    enum ScrollDestination {
        case currentMedia
        case specificItem(AnyHashable)
    }

    struct ScrollRequest {
        let destination: ScrollDestination
        let animate: Bool
    }
}
