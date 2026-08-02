//
//  AlbumEntity.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit

/// An App Intents entity representing an album in the MPD database.
@AppEntity(schema: .audio.album)
struct AlbumEntity {
    static let defaultQuery = AlbumEntityQuery()

    let id: String

    @Property(title: "Title")
    var title: String

    @Property(title: "Artist")
    var artistName: String

    @Property(title: "Artists")
    var artists: [ArtistEntity]

    @Property(title: "UPC")
    var universalProductCode: String?

    init(album: Album) {
        id = album.id
        title = album.title
        artistName = album.artist.name
        artists = [ArtistEntity(artist: album.artist)]
    }

    /// An `Album` carrying just enough for playback commands, which match
    /// songs by the album's title and artist tags.
    var album: Album {
        Album(file: id, title: title, titleSort: nil,
              artist: Artist(file: id, name: artistName, nameSort: nil))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(artistName)",
            image: .init(systemName: "opticaldisc"),
        )
    }
}

struct AlbumEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AlbumEntity] {
        let ids = Set(identifiers)

        return try await ConnectionManager.command {
            try await $0.getAlbums()
        }.filter { ids.contains($0.id) }.map(AlbumEntity.init)
    }

    func suggestedEntities() async throws -> [AlbumEntity] {
        []
    }
}

extension AlbumEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [AlbumEntity] {
        let query = string.folded

        return try await ConnectionManager.command {
            try await $0.getAlbums()
        }.filter {
            $0.title.folded.contains(query) || $0.artist.name.folded.contains(query)
        }.map(AlbumEntity.init)
    }
}
