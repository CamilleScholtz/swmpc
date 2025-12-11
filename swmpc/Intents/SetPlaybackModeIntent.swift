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
        let newState: Bool
        let modeName: String

        switch mode {
        case .shuffle:
            newState = await !(mpd.status.isRandom ?? false)
            try await ConnectionManager.command {
                try await $0.random(newState)
            }
            modeName = "Shuffle"
        case .repeat:
            newState = await !(mpd.status.isRepeat ?? false)
            try await ConnectionManager.command {
                try await $0.repeat(newState)
            }
            modeName = "Repeat"
        case .consume:
            newState = await !(mpd.status.isConsume ?? false)
            try await ConnectionManager.command {
                try await $0.consume(newState)
            }
            modeName = "Consume"
        }

        return .result(dialog: IntentDialog("\(modeName) \(newState ? "enabled" : "disabled")"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle \(\.$mode)")
    }
}
