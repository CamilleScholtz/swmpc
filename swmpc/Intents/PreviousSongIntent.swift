//
//  PreviousSongIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct PreviousSongIntent: AppIntent {
    static let title: LocalizedStringResource = "Previous Song"
    static let description = IntentDescription("Go back to the previous song")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ConnectionManager.command().previous()

        guard let song = mpd.status.song else {
            return .result(dialog: IntentDialog("Playing previous song"))
        }

        return .result(dialog: IntentDialog(stringLiteral: "Playing \(song.title) by \(song.artist)"))
    }

    static let openAppWhenRun: Bool = false
}
