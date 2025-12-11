//
//  ClearQueueIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 11/12/2025.
//

import AppIntents
import MPDKit
import SwiftUI

struct ClearQueueIntent: AppIntent, AudioPlaybackIntent {
    static let title: LocalizedStringResource = "Clear Queue"
    static let description = IntentDescription("Clear all songs from the playback queue")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ConnectionManager.command {
            try await $0.clearQueue()
        }

        return .result(dialog: IntentDialog("Queue cleared"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Clear the playback queue")
    }
}
