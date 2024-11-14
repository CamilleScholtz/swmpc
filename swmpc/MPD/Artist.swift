//
//  Artist.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct Artist: Identifiable, Sendable {
    let id: URL

    let name: String
    var albums: [Album] = []
}
