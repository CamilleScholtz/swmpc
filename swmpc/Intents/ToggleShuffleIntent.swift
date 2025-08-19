//
//  ToggleShuffleIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct ToggleShuffleIntent: AppIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Toggle Shuffle"
    static let description = IntentDescription("Enable or disable shuffle mode")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ConnectionManager.command().random(!(mpd.status.isRandom ?? false))

        return await .result(dialog: IntentDialog(!(mpd.status.isRandom ?? false) ? "Shuffle enabled" : "Shuffle disabled"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle shuffle mode")
    }
}
