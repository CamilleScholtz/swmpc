//
//  NextSongIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import MPDKit
import SwiftUI

struct NextSongIntent: AppIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Next Song"
    static let description = IntentDescription("Skip to the next song in the queue")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let song = try await command {
            try await $0.next()
            return try await $0.getStatusData().song
        }

        guard let song else {
            return .result(dialog: IntentDialog("Playing next song"))
        }

        return .result(dialog: IntentDialog(stringLiteral: "Playing \(song.title) by \(song.artist)"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Skip to next song")
    }
}
