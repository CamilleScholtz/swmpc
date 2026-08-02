//
//  ArtistEntity.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit

/// An App Intents entity representing an artist in the MPD database.
@AppEntity(schema: .audio.artist)
struct ArtistEntity {
    static let defaultQuery = ArtistEntityQuery()

    let id: String

    @Property(title: "Name")
    var name: String

    init(artist: Artist) {
        id = artist.id
        name = artist.name
    }

    /// An `Artist` carrying just enough for playback commands, which match
    /// songs by the artist's name tag.
    var artist: Artist {
        Artist(file: id, name: name, nameSort: nil)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: "music.microphone"),
        )
    }
}

struct ArtistEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ArtistEntity] {
        let ids = Set(identifiers)

        return try await ConnectionManager.command {
            try await $0.getArtists()
        }.filter { ids.contains($0.id) }.map(ArtistEntity.init)
    }

    func suggestedEntities() async throws -> [ArtistEntity] {
        []
    }
}

extension ArtistEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [ArtistEntity] {
        let query = string.folded

        return try await ConnectionManager.command {
            try await $0.getArtists()
        }.filter {
            $0.name.folded.contains(query)
        }.map(ArtistEntity.init)
    }
}
