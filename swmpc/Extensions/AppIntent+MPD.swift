//
//  AppIntent+MPD.swift
//  swmpc
//
//  Created by Camille Scholtz on 27/05/2025.
//

import AppIntents

extension AppIntent {
    @MainActor
    var mpd: MPD {
        #if os(iOS)
            Delegate.mpd
        #elseif os(macOS)
            AppDelegate.shared.mpd
        #endif
    }
}
