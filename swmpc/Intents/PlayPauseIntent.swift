//
//  PlayPauseIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct PlayPauseIntent: AppIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause"
    static let description = IntentDescription("Toggle playback of the current song")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ConnectionManager.command().pause(mpd.status.isPlaying)

        return await .result(dialog: IntentDialog(mpd.status.isPlaying ? "Paused playback" : "Resumed playback"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle playback")
    }
}
