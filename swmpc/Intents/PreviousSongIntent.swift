//
//  PreviousSongIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct PreviousSongIntent: AppIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Previous Song"
    static let description = IntentDescription("Go back to the previous song")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ConnectionManager.command {
            try await $0.previous()
        }

        guard let song = await mpd.status.song else {
            return .result(dialog: IntentDialog("Playing previous song"))
        }

        return .result(dialog: IntentDialog(stringLiteral: "Playing \(song.title) by \(song.artist)"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Go to previous song")
    }
}
