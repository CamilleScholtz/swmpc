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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let isRandom = await MainActor.run {
            #if os(iOS)
                Delegate.mpd.status.isRandom
            #elseif os(macOS)
                AppDelegate.shared?.mpd.status.isRandom
            #endif
        }

        try await ConnectionManager.command().random(!(isRandom ?? false))

        return .result(dialog: IntentDialog(!(isRandom ?? false) ? "Shuffle enabled" : "Shuffle disabled"))
    }

    static let openAppWhenRun: Bool = false
}
