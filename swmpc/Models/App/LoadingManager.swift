//
//  LoadingManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 25/03/2025.
//

import SwiftUI

@Observable
final class LoadingManager {
    @MainActor static let shared = LoadingManager()
    
    var isLoading: Bool = false
    
    private init() {}

    @MainActor
    func show() {
        isLoading = true
    }

    @MainActor
    func hide() {
        isLoading = false
    }
}
