//
//  NavigationManager.swift
//  swmpc
//
//  Created by Claude on 01/04/2025.
//

import SwiftUI

@Observable
class NavigationManager {
    var path = NavigationPath()
    var selection: SidebarDestination = .albums {
        didSet {
            if oldValue != selection {
                reset()
            }
        }
    }

    func navigate(to destination: any Hashable) {
        path.append(destination)
    }

    func back() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func reset() {
        path = NavigationPath()
    }
}
