//
//  FavoriteSongIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit
import SwiftUI

struct FavoriteSongIntent: AppIntent {
    static let title: LocalizedStringResource = "Favorite Current Song"
    static let description = IntentDescription("Add or remove the currently playing song from Favorites")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let song = try await command {
            try await $0.getStatusData()
        }.song
        guard let song else {
            return .result(dialog: IntentDialog("Nothing is currently playing"))
        }

        let favorites = (try? await command {
            try await $0.getSongs(from: Source.favorites)
        }) ?? []
        let isFavorited = favorites.contains { $0.file == song.file }

        if isFavorited {
            try await command {
                try await $0.remove(songs: [song], from: .favorites)
            }
        } else {
            try await command {
                try await $0.add(songs: [song], to: .favorites)
            }
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .playlistModifiedNotification,
                                            object: nil)
        }

        return .result(dialog: isFavorited
            ? IntentDialog(stringLiteral: "Removed \(song.title) from Favorites")
            : IntentDialog(stringLiteral: "Added \(song.title) to Favorites"))
    }

    static let openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        Summary("Add or remove the current song from Favorites")
    }
}
