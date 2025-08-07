//
//  AppIntent+MPD.swift
//  swmpc
//
//  Created by Camille Scholtz on 27/05/2025.
//

import AppIntents

extension AppIntent {
    /// Provides access to the shared MPD instance appropriate for the current
    /// platform.
    ///
    /// On iOS, accesses the MPD instance from the global Delegate.
    /// On macOS, accesses the MPD instance from the shared AppDelegate.
    @MainActor
    var mpd: MPD {
        #if os(iOS)
            Delegate.mpd
        #elseif os(macOS)
            AppDelegate.shared.mpd
        #endif
    }
}
