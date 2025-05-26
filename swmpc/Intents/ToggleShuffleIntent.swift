//
//  ToggleShuffleIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct ToggleShuffleIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Shuffle"
    static let description = IntentDescription("Enable or disable shuffle mode")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ConnectionManager.command().repeat(!(mpd.status.isRandom ?? false))

        return .result(dialog: IntentDialog(!(mpd.status.isRepeat ?? false) ? "Shuffle enabled" : "Shuffle disabled"))
    }

    static let openAppWhenRun: Bool = false
}
