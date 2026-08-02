//
//  PlaylistEntity.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit

/// The owner of a playlist, as required by the `.audio.playlist` schema.
@UnionValue
enum PlaylistOwner {
    case person(IntentPerson)
    case string(String)
}

/// An App Intents entity representing an MPD playlist.
///
/// MPD identifies playlists by name, so the name doubles as the entity
/// identifier. The `Favorites` playlist is included, unlike in the sidebar.
@AppEntity(schema: .audio.playlist)
struct PlaylistEntity {
    static let defaultQuery = PlaylistEntityQuery()

    let id: String

    @Property(title: "Title")
    var title: String

    @Property(title: "Owner")
    var owner: PlaylistOwner?

    @Property(title: "Curated for Me")
    var curatedForMe: Bool?

    @Property(title: "Created by Me")
    var createdByMe: Bool?

    init(id: String) {
        self.id = id
        title = id
        curatedForMe = false
        createdByMe = true
    }

    var playlist: Playlist {
        Playlist(name: id)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(id)",
            image: .init(systemName: playlist.symbol.rawValue),
        )
    }
}

extension PlaylistEntity: IndexedEntity {}

struct PlaylistEntityQuery: EntityQuery {
    private func allEntities() async throws -> [PlaylistEntity] {
        try await ConnectionManager.command {
            try await $0.getPlaylists()
        }.map { PlaylistEntity(id: $0.name) }
    }

    func entities(for identifiers: [String]) async throws -> [PlaylistEntity] {
        let existing = try await Set(allEntities().map(\.id))

        return identifiers.filter { existing.contains($0) }.map {
            PlaylistEntity(id: $0)
        }
    }

    func suggestedEntities() async throws -> [PlaylistEntity] {
        try await allEntities()
    }
}

extension PlaylistEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [PlaylistEntity] {
        try await allEntities().filter {
            $0.id.localizedCaseInsensitiveContains(string)
        }
    }
}
