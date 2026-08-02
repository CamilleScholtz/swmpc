//
//  AdjustVolumeIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit
import SwiftUI

enum VolumeDirection: String, AppEnum {
    case up
    case down

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Direction")

    static let caseDisplayRepresentations: [VolumeDirection: DisplayRepresentation] = [
        .up: DisplayRepresentation(title: "Up"),
        .down: DisplayRepresentation(title: "Down"),
    ]
}

struct AdjustVolumeIntent: AppIntent {
    static let title: LocalizedStringResource = "Adjust Volume"
    static let description = IntentDescription("Turn the playback volume of the MPD server up or down")

    @Parameter(title: "Direction", description: "Whether to turn the volume up or down")
    var direction: VolumeDirection

    @Parameter(title: "Amount", description: "How many percentage points to change the volume by",
               default: 10, inclusiveRange: (1, 100))
    var amount: Int

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let volume = try await command {
            try await $0.getStatusData()
        }.volume
        guard let volume else {
            return .result(dialog: IntentDialog("Volume is not available for the current output"))
        }

        let target = direction == .up
            ? min(volume + amount, 100)
            : max(volume - amount, 0)

        try await command {
            try await $0.setVolume(target)
        }

        return .result(dialog: IntentDialog(stringLiteral: "Volume set to \(target) percent"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Turn volume \(\.$direction) by \(\.$amount) percent")
    }
}
