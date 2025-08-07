//
//  ToggleRepeatIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct ToggleRepeatIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Repeat"
    static let description = IntentDescription("Enable or disable repeat mode")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ConnectionManager.command().repeat(!(mpd.status.isRepeat ?? false))

        return await .result(dialog: IntentDialog(!(mpd.status.isRepeat ?? false) ? "Repeat enabled" : "Repeat disabled"))
    }

    static let openAppWhenRun: Bool = false
}
