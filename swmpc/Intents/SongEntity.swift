//
//  SongEntity.swift
//  swmpc
//
//  Created by Camille Scholtz on 02/08/2026.
//

import AppIntents
import MPDKit

/// An App Intents entity representing a song, so intents can hand song
/// metadata to Shortcuts for further use.
@AppEntity(schema: .audio.song)
struct SongEntity {
    static let defaultQuery = SongEntityQuery()

    let id: String

    @Property(title: "Title")
    var title: String

    @Property(title: "Artist")
    var artistName: String

    @Property(title: "Artists")
    var artists: [ArtistEntity]

    @Property(title: "Album")
    var albumTitle: String?

    @Property(title: "Album Entity")
    var album: AlbumEntity?

    @Property(title: "Composer")
    var composerName: String?

    @Property(title: "Composers")
    var composers: [ArtistEntity]

    @Property(title: "ISRC")
    var internationalStandardRecordingCode: String?

    @Property(title: "Duration")
    var duration: Double

    init(song: Song) {
        id = song.file
        title = song.title
        artistName = song.artist
        artists = [ArtistEntity(artist: song.album.artist)]
        albumTitle = song.album.title
        album = AlbumEntity(album: song.album)
        composerName = song.composer
        composers = []
        duration = song.duration
    }

    /// A `Song` carrying just enough for playback commands, which only use
    /// the file path.
    var song: Song {
        Song(file: id, identifier: nil, position: nil, artist: artistName,
             artistSort: nil, title: title, titleSort: nil, duration: duration,
             disc: 0, track: 0, genre: nil, composer: nil, performer: nil,
             conductor: nil, ensemble: nil, mood: nil, comment: nil,
             album: Album(file: id, title: albumTitle ?? "", titleSort: nil,
                          artist: Artist(file: id, name: artistName,
                                         nameSort: nil)))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(artistName) – \(albumTitle ?? "")",
            image: .init(systemName: "music.note"),
        )
    }
}

struct SongEntityQuery: EntityQuery {
    /// Resolves identifiers against the queue first, falling back to the full
    /// database only when some identifier is not queued.
    func entities(for identifiers: [String]) async throws -> [SongEntity] {
        let files = Set(identifiers)

        let queued = try await ConnectionManager.command {
            try await $0.getSongs(from: Source.queue)
        }.filter { files.contains($0.file) }

        guard queued.count < files.count else {
            return queued.map(SongEntity.init)
        }

        return try await ConnectionManager.command {
            try await $0.getSongs(from: Source.database)
        }.filter { files.contains($0.file) }.map(SongEntity.init)
    }
}

extension SongEntityQuery: EntityStringQuery {
    func entities(matching string: String) async throws -> [SongEntity] {
        let query = string.folded

        return try await ConnectionManager.command {
            try await $0.getSongs(from: Source.database)
        }.filter {
            $0.title.folded.contains(query)
        }.map(SongEntity.init)
    }
}
