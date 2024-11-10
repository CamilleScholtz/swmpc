//
//  Artist.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

struct Artist: Mediable, Identifiable, Sendable {
    var id: String

    var name: String
    var albums: [Album] = []
}
