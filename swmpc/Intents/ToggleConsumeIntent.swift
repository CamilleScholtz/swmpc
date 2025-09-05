//
//  ToggleConsumeIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct ToggleConsumeIntent: AppIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Toggle Consume"
    static let description = IntentDescription("Enable or disable consume mode")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ConnectionManager.command().consume(!(mpd.status.isConsume ?? false))

        return await .result(dialog: IntentDialog(!(mpd.status.isConsume ?? false) ? "Consume enabled" : "Consume disabled"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle consume mode")
    }
}
