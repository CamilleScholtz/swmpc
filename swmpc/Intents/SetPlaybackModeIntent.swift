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
        let dialog: IntentDialog

        switch mode {
        case .shuffle:
            let newState = await !(mpd.status.isRandom ?? false)
            try await ConnectionManager.command {
                try await $0.random(newState)
            }
            dialog = newState ? IntentDialog("Shuffle enabled") : IntentDialog("Shuffle disabled")
        case .repeat:
            let newState = await !(mpd.status.isRepeat ?? false)
            try await ConnectionManager.command {
                try await $0.repeat(newState)
            }
            dialog = newState ? IntentDialog("Repeat enabled") : IntentDialog("Repeat disabled")
        case .consume:
            let newState = await !(mpd.status.isConsume ?? false)
            try await ConnectionManager.command {
                try await $0.consume(newState)
            }
            dialog = newState ? IntentDialog("Consume enabled") : IntentDialog("Consume disabled")
        }

        return .result(dialog: dialog)
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle \(\.$mode)")
    }
}
