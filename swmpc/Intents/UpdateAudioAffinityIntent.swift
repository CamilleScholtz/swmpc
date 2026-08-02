//
//  UpdateAudioAffinityIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit
import SwiftUI

@AppEnum(schema: .audio.affinityState)
enum AffinityState: String {
    case like
    case dislike
    case unset

    static let caseDisplayRepresentations: [AffinityState: DisplayRepresentation] = [
        .like: DisplayRepresentation(title: "Like"),
        .dislike: DisplayRepresentation(title: "Dislike"),
        .unset: DisplayRepresentation(title: "Unset"),
    ]
}

/// Handles "I like this song" style requests via the
/// `.audio.updateAudioAffinity` schema by adding the target's songs to (or
/// removing them from) the `Favorites` playlist.
@AppIntent(schema: .audio.updateAudioAffinity)
struct UpdateAudioAffinityIntent {
    var target: AudioItem
    var affinityState: AffinityState

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let songs: [Song]
        let name: String

        switch target {
        case let .song(entity):
            songs = [entity.song]
            name = entity.title
        case let .album(entity):
            songs = try await entity.album.getSongs()
            name = entity.title
        case let .artist(entity):
            var collected: [Song] = []
            for album in try await entity.artist.getAlbums() {
                try await collected.append(contentsOf: album.getSongs())
            }
            songs = collected
            name = entity.name
        case .playlist:
            return .result(dialog: IntentDialog("Playlists cannot be added to Favorites"))
        }

        guard !songs.isEmpty else {
            return .result(dialog: IntentDialog(stringLiteral: "No songs found for \(name)"))
        }

        let favorites = (try? await command {
            try await $0.getSongs(from: Source.favorites)
        }) ?? []
        let files = Set(favorites.map(\.file))
        let isFavorited = songs.contains { files.contains($0.file) }

        let dialog: IntentDialog
        switch (affinityState, isFavorited) {
        case (.like, false):
            try await command {
                try await $0.add(songs: songs, to: .favorites)
            }
            dialog = IntentDialog(stringLiteral: "Added \(name) to Favorites")
        case (.like, true):
            dialog = IntentDialog(stringLiteral: "\(name) is already in Favorites")
        case (.dislike, true), (.unset, true):
            try await command {
                try await $0.remove(songs: songs, from: .favorites)
            }
            dialog = IntentDialog(stringLiteral: "Removed \(name) from Favorites")
        case (.dislike, false), (.unset, false):
            dialog = IntentDialog(stringLiteral: "\(name) is not in Favorites")
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .playlistModifiedNotification,
                                            object: nil)
        }

        return .result(dialog: dialog)
    }
}
