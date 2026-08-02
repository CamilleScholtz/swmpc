//
//  PlayPauseIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import MPDKit
import SwiftUI

struct PlayPauseIntent: AppIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play or Pause"
    static let description = IntentDescription("Toggle playback of the current song")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let wasPlaying = try await command {
            let isPlaying = try await $0.getStatusData().state == .play
            try await $0.pause(isPlaying)

            return isPlaying
        }

        return .result(dialog: IntentDialog(wasPlaying ? "Paused playback" : "Resumed playback"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle playback")
    }
}
