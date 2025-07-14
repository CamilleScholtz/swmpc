//
//  LoadingState.swift
//  swmpc
//
//  Created by Camille Scholtz on 14/07/2025.
//

import SwiftUI

/// Represents the loading state of the MPD client.
@Observable final class LoadingState {
    private var loadingStates: [Source: Bool] = [:]

    func isLoading(_ sources: [Source]) -> Bool {
        sources.contains { loadingStates[$0] == true }
    }

    func setLoading(_ loading: Bool, for source: Source) {
        loadingStates[source] = loading
    }
}
