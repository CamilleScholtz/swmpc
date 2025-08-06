//
//  CurrentSongIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct CurrentSongIntent: AppIntent {
    static let title: LocalizedStringResource = "What's Playing"
    static let description = IntentDescription("Get information about the currently playing song")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let song = await mpd.status.song else {
            return .result(dialog: IntentDialog("Nothing is currently playing"))
        }

        return .result(dialog: IntentDialog(stringLiteral: "Now playing: \(song.title) by \(song.artist)"))
    }

    static let openAppWhenRun: Bool = false
}
