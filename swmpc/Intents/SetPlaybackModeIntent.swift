//
//  SetPlaybackModeIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 11/12/2025.
//

import AppIntents
import MPDKit
import SwiftUI

enum PlaybackMode: String, AppEnum {
    case shuffle
    case `repeat`
    case consume

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Playback Mode")

    static let caseDisplayRepresentations: [PlaybackMode: DisplayRepresentation] = [
        .shuffle: DisplayRepresentation(title: "Shuffle", subtitle: "Play songs in random order"),
        .repeat: DisplayRepresentation(title: "Repeat", subtitle: "Repeat the queue when finished"),
        .consume: DisplayRepresentation(title: "Consume", subtitle: "Remove songs after playing"),
    ]
}

struct SetPlaybackModeIntent: AppIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Toggle Playback Mode"
    static let description = IntentDescription("Toggle a playback mode (shuffle, repeat, or consume)")

    @Parameter(title: "Mode", description: "The playback mode to toggle")
    var mode: PlaybackMode

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let newState = try await command { [mode] connection in
            let data = try await connection.getStatusData()

            switch mode {
            case .shuffle:
                let value = !(data.isRandom ?? false)
                try await connection.random(value)
                return value
            case .repeat:
                let value = !(data.isRepeat ?? false)
                try await connection.repeat(value)
                return value
            case .consume:
                let value = !(data.isConsume ?? false)
                try await connection.consume(value)
                return value
            }
        }

        let dialog: IntentDialog = switch (mode, newState) {
        case (.shuffle, true): IntentDialog("Shuffle enabled")
        case (.shuffle, false): IntentDialog("Shuffle disabled")
        case (.repeat, true): IntentDialog("Repeat enabled")
        case (.repeat, false): IntentDialog("Repeat disabled")
        case (.consume, true): IntentDialog("Consume enabled")
        case (.consume, false): IntentDialog("Consume disabled")
        }

        return .result(dialog: dialog)
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle \(\.$mode)")
    }
}
