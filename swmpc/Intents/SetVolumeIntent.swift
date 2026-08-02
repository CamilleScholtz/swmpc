//
//  SetVolumeIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit
import SwiftUI

struct SetVolumeIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Volume"
    static let description = IntentDescription("Set the playback volume of the MPD server")

    @Parameter(title: "Volume", description: "The volume level (0-100)",
               inclusiveRange: (0, 100))
    var volume: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await command {
            try await $0.setVolume(volume)
        }

        return .result(dialog: IntentDialog(stringLiteral: "Volume set to \(volume) percent"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Set volume to \(\.$volume) percent")
    }
}
