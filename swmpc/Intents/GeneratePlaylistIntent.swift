//
//  GeneratePlaylistIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit
import SwiftUI

struct GeneratePlaylistIntent: AppIntent, LongRunningIntent, CancellableIntent {
    static let title: LocalizedStringResource = "Generate Playlist"
    static let description = IntentDescription("Use AI to fill the queue or a playlist with music matching a description")

    @Parameter(title: "Description", description: "What the music should be like",
               requestValueDialog: "What kind of music do you want?")
    var prompt: String

    @Parameter(title: "Playlist", description: "The playlist to add songs to; leave empty to use the queue")
    var playlist: PlaylistEntity?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let target: IntelligenceTarget = if let playlist {
            .playlist(playlist.playlist)
        } else {
            .queue
        }

        do {
            let songs = try await performBackgroundTask {
                try await withIntentCancellationHandler {
                    progress.totalUnitCount = 100

                    return try await IntelligenceManager.fill(
                        target: target,
                        prompt: prompt,
                        timeout: 120,
                    ) { fraction, message in
                        progress.completedUnitCount = Int64(fraction * 100)
                        progress.localizedDescription = message
                    }
                } onCancel: { _ in }
            }
            let destination = playlist.map { "playlist \($0.id)" } ?? "the queue"

            return .result(dialog: IntentDialog(stringLiteral: "Added \(songs.count) songs to \(destination)"))
        } catch let error as IntelligenceManagerError {
            return .result(dialog: IntentDialog(stringLiteral: error.errorDescription ?? "Something went wrong"))
        } catch is CancellationError {
            return .result(dialog: IntentDialog("Playlist generation cancelled"))
        } catch {
            throw AppIntentError(description: "Playlist generation failed")
        }
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Generate \(\.$prompt) into \(\.$playlist)")
    }
}
