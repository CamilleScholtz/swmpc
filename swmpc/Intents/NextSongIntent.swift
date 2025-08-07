//
//  NextSongIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct NextSongIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Song"
    static let description = IntentDescription("Skip to the next song in the queue")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ConnectionManager.command().next()

        guard let song = await mpd.status.song else {
            return .result(dialog: IntentDialog("Playing next song"))
        }

        return .result(dialog: IntentDialog(stringLiteral: "Playing \(song.title) by \(song.artist)"))
    }

    static let openAppWhenRun: Bool = false
}
