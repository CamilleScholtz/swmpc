//
//  PlayPauseIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct PlayPauseIntent: AppIntent {
    static let title: LocalizedStringResource = "Play or Pause"
    static let description = IntentDescription("Toggle playback of the current song")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let isPlaying = await MainActor.run {
            #if os(iOS)
                Delegate.mpd.status.isPlaying
            #elseif os(macOS)
                AppDelegate.shared?.mpd.status.isPlaying
            #endif
        }

        try await ConnectionManager.command().pause(isPlaying)

        return .result(dialog: IntentDialog(isPlaying ? "Paused playback" : "Resumed playback"))
    }

    static let openAppWhenRun: Bool = false
}
