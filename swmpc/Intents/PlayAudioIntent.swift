//
//  PlayAudioIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit
import SwiftUI

/// The kinds of audio content Siri can ask swmpc to play or act on.
@UnionValue
enum AudioItem {
    case song(SongEntity)
    case album(AlbumEntity)
    case artist(ArtistEntity)
    case playlist(PlaylistEntity)
}

@AppEnum(schema: .audio.playbackAttributes)
enum PlaybackAttributes: String {
    case shuffle
    case `repeat`

    static let caseDisplayRepresentations: [PlaybackAttributes: DisplayRepresentation] = [
        .shuffle: DisplayRepresentation(title: "Shuffle"),
        .repeat: DisplayRepresentation(title: "Repeat"),
    ]
}

@AppEnum(schema: .audio.queueInsertionLocation)
enum QueueInsertionLocation: String {
    case now
    case next
    case tail

    static let caseDisplayRepresentations: [QueueInsertionLocation: DisplayRepresentation] = [
        .now: DisplayRepresentation(title: "Now"),
        .next: DisplayRepresentation(title: "Next"),
        .tail: DisplayRepresentation(title: "Later"),
    ]
}

@AppEntity(schema: .audio.warmupAudioQueueResult)
struct WarmupAudioQueueResult {
    static let defaultQuery = Query()

    let id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }

    struct Query: EntityStringQuery {
        func entities(for identifiers: [String]) async throws -> [WarmupAudioQueueResult] {
            identifiers.map { WarmupAudioQueueResult(id: $0) }
        }

        func entities(matching _: String) async throws -> [WarmupAudioQueueResult] {
            []
        }
    }
}

/// Plays audio content via the `.audio.playAudio` schema, so natural Siri
/// phrasing works without a memorized App Shortcut phrase.
@AppIntent(schema: .audio.playAudio)
struct PlayAudioIntent: AudioPlaybackIntent {
    var audioEntity: AudioItem
    var playbackAttributes: Set<PlaybackAttributes>
    var queueLocation: QueueInsertionLocation?
    var warmupAudioQueueResult: WarmupAudioQueueResult?

    func perform() async throws -> some IntentResult {
        if !playbackAttributes.isEmpty {
            try await command { [playbackAttributes] connection in
                if playbackAttributes.contains(.shuffle) {
                    try await connection.random(true)
                }
                if playbackAttributes.contains(.repeat) {
                    try await connection.repeat(true)
                }
            }
        }

        switch audioEntity {
        case let .song(entity):
            try await command {
                try await $0.play(entity.song)
            }
        case let .album(entity):
            try await command {
                try await $0.play(entity.album)
            }
        case let .artist(entity):
            try await command {
                try await $0.play(entity.artist)
            }
        case let .playlist(entity):
            try await command {
                try await $0.loadPlaylist(entity.playlist)
            }
        }

        return .result()
    }
}
