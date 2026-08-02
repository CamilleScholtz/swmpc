//
//  CurrentSongIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import MPDKit
import SwiftUI

struct CurrentSongIntent: AppIntent {
    static let title: LocalizedStringResource = "What's Playing"
    static let description = IntentDescription("Get information about the currently playing song")

    func perform() async throws -> some IntentResult & ReturnsValue<SongEntity?> & ProvidesDialog & ShowsSnippetIntent {
        let song = try await command {
            try await $0.getStatusData()
        }.song
        guard let song else {
            return .result(value: nil,
                           dialog: IntentDialog("Nothing is currently playing"),
                           snippetIntent: CurrentSongSnippetIntent())
        }

        return .result(value: SongEntity(song: song),
                       dialog: IntentDialog(stringLiteral: "Now playing: \(song.title) by \(song.artist)"),
                       snippetIntent: CurrentSongSnippetIntent())
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Get current song info")
    }
}
