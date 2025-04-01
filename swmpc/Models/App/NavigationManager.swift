//
//  NavigationManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 01/04/2025.
//

import SwiftUI

@Observable
class NavigationManager {
    var path = NavigationPath()

    var categoryDestination: CategoryDestination = .albums
    var contentDestination: ContentDestination?
}
