//
//  PlayPlaylistIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit
import SwiftUI

struct PlayPlaylistIntent: AppIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Play Playlist"
    static let description = IntentDescription("Clear the queue, load a playlist, and start playing it")

    @Parameter(title: "Playlist", description: "The playlist to play")
    var playlist: PlaylistEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await command {
            try await $0.loadPlaylist(playlist.playlist)
        }

        return .result(dialog: IntentDialog(stringLiteral: "Playing playlist \(playlist.id)"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$playlist)")
    }
}
