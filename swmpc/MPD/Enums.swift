//
//  Enums.swift
//  swmpc
//
//  Created by Camille Scholtz on 10/11/2024.
//

import SwiftUI

enum PlayerState {
    case play
    case pause
    case stop
}

enum MediaType {
    case album
    case artist
    case song
    case playlist
}

struct Category: Identifiable, Hashable {
    let id: MediaType
    let label: String
    let image: String
    var list = true
}
