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
        let isRepeat = await MainActor.run {
            #if os(iOS)
                Delegate.mpd.status.isRepeat
            #elseif os(macOS)
                AppDelegate.shared?.mpd.status.isRepeat
            #endif
        }

        try await ConnectionManager.command().repeat(!(isRepeat ?? false))

        return .result(dialog: IntentDialog(!(isRepeat ?? false) ? "Repeat enabled" : "Repeat disabled"))
    }

    static let openAppWhenRun: Bool = false
}
