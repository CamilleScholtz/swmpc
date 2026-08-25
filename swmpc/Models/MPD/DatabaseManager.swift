//
//  DatabaseManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import MPDKit
import Observation

/// The result of a library-wide search, grouped per media type.
struct SearchResults: Sendable {
    /// The artists matching the query.
    let artists: [Artist]

    /// The albums matching the query.
    let albums: [Album]

    /// The songs matching the query.
    let songs: [Song]

    /// How many albums each matching artist has, keyed by artist identifier.
    let artistAlbumCounts: [String: Int]

    /// An empty result, used before a query has been run.
    static let empty = SearchResults(artists: [], albums: [], songs: [],
                                     artistAlbumCounts: [:])

    /// Indicates whether nothing in the library matched.
    var isEmpty: Bool {
        artists.isEmpty && albums.isEmpty && songs.isEmpty
    }
}

/// Manages the MPD database, handling artists, albums, and song queries.
@Observable final class DatabaseManager {
    /// The state manager, used to indicate when data is being fetched.
    @ObservationIgnored private let state: StateManager

    /// Creates a new database manager.
    ///
    /// - Parameter state: An instance of `StateManager` to report back loading
    ///                    activity for UI updates.
    init(state: StateManager) {
        self.state = state
    }

    /// The collection of currently loaded media items (e.g., albums, artists,
    /// or songs) based on the active `type`.
    private(set) var media: MediaCollection?

    /// How many albums each artist has, keyed by artist identifier.
    ///
    /// Filled in alongside the artist list, which is itself derived from the
    /// albums, so the rows don't each have to query the server for their own
    /// count.
    private(set) var artistAlbumCounts: [String: Int] = [:]

    /// The current type of media being displayed or managed (e.g., albums,
    /// artists).
    private(set) var type: MediaType = .album

    /// The current sort option being used.
    private(set) var sort: MPDKit.SortDescriptor = .default

    /// Sets the media type and/or sort descriptor and fetches corresponding
    /// media from MPD.
    ///
    /// This method only fetches new data if the type or sort has changed.
    ///
    /// A refresh that passes neither a type nor a sort comes from a database
    /// change, which also invalidates the collections cached for searching.
    ///
    /// - Parameters:
    ///   - connection: The connection to load over.
    ///   - type: The media type to fetch (album, artist, song, or playlist).
    ///           If `nil`, retains the current type.
    ///   - sort: The sort descriptor for ordering results.
    ///           If `nil`, retains the current sort.
    /// - Throws: An error if the MPD connection fails or the fetch is
    ///           cancelled.
    func set<Mode: ConnectionMode>(on connection: ConnectionManager<Mode>,
                                   type: MediaType? = nil,
                                   sort: MPDKit.SortDescriptor? = nil)
        async throws
    {
        defer { state.isLoading = false }

        guard type != self.type || sort != self.sort else {
            return
        }

        let sortToUse: MPDKit.SortDescriptor = sort ?? self.sort

        var newMedia: MediaCollection?
        var newArtistAlbumCounts: [String: Int] = [:]

        switch type ?? self.type {
        case .album:
            let albums = try await connection.getAlbums(sort: sortToUse)

            newMedia = .albums(albums)
        case .artist:
            let result = try await connection.getArtistsWithAlbumCounts(
                sort: sortToUse,
            )

            newMedia = .artists(result.artists)
            newArtistAlbumCounts = result.albumCounts
        case .song:
            let songs = try await connection.getSongs(from: Source.database,
                                                      sort: sortToUse)

            newMedia = .songs(songs)
        case .playlist:
            newMedia = nil
        }

        try Task.checkCancellation()

        media = newMedia
        artistAlbumCounts = newArtistAlbumCounts

        if type == nil, sort == nil {
            library = nil
        }

        if let type {
            self.type = type
        }
        if let sort {
            self.sort = sort
        }
    }

    /// Checks if a song matches the search query against specified fields.
    ///
    /// - Parameters:
    ///   - song: The song to check.
    ///   - query: The folded search query string.
    ///   - fields: Set of field names to search ("title", "artist", "album").
    /// - Returns: `true` if the song matches the query in any of the specified
    ///            fields.
    private nonisolated func matches(_ song: Song, query: String,
                                     fields: Set<String>) -> Bool
    {
        (fields.contains("title") && (contains(song.title, query) || contains(song.titleSort, query))) ||
            (fields.contains("artist") && (contains(song.artist, query) || contains(song.artistSort, query))) ||
            (fields.contains("album") && (contains(song.album.title, query) || contains(song.album.titleSort, query))) ||
            (fields.contains("genre") && contains(song.genre, query)) ||
            (fields.contains("composer") && contains(song.composer, query)) ||
            (fields.contains("performer") && contains(song.performer, query)) ||
            (fields.contains("conductor") && contains(song.conductor, query)) ||
            (fields.contains("ensemble") && contains(song.ensemble, query)) ||
            (fields.contains("mood") && contains(song.mood, query)) ||
            (fields.contains("comment") && contains(song.comment, query))
    }

    /// Checks if an album matches the search query against specified fields.
    ///
    /// - Parameters:
    ///   - album: The album to check.
    ///   - query: The folded search query string.
    ///   - fields: Set of field names to search ("title", "artist").
    /// - Returns: `true` if the album matches the query in any of the
    ///            specified fields.
    private nonisolated func matches(_ album: Album, query: String,
                                     fields: Set<String>) -> Bool
    {
        (fields.contains("title") && (contains(album.title, query) || contains(album.titleSort, query))) ||
            (fields.contains("artist") && (contains(album.artist.name, query) || contains(album.artist.nameSort, query)))
    }

    /// Checks if an artist matches the search query against specified fields.
    ///
    /// - Parameters:
    ///   - artist: The artist to check.
    ///   - query: The folded search query string.
    ///   - fields: Set of field names to search ("artist").
    /// - Returns: `true` if the artist matches the query.
    private nonisolated func matches(_ artist: Artist, query: String,
                                     fields: Set<String>) -> Bool
    {
        fields.contains("artist") && (contains(artist.name, query) || contains(artist.nameSort, query))
    }

    /// Performs a localized case-insensitive comparison to check if text
    /// contains query.
    ///
    /// - Parameters:
    ///   - text: The optional text to search within.
    ///   - query: The folded query string.
    /// - Returns: `true` if the text contains the query (diacritic and case-insensitive).
    private nonisolated func contains(_ text: String?, _ query: String) -> Bool {
        guard let text else {
            return false
        }

        return text.folded.contains(query)
    }

    /// The library collections a search matches against.
    private struct Library: Sendable {
        let artists: [Artist]
        let albums: [Album]
        let songs: [Song]
        let artistAlbumCounts: [String: Int]
    }

    /// The collections backing library-wide search, cached until the database
    /// changes since every keystroke matches against all of them.
    @ObservationIgnored private var library: Library?

    /// The preparation currently in flight, so that a caller overlapping
    /// with it awaits the same fetch instead of starting a second one.
    @ObservationIgnored private var preparation: Task<Void, any Error>?

    /// Loads the collections that `searchLibrary(_:artistFields:albumFields:songFields:)`
    /// matches against, unless they are already cached.
    ///
    /// The albums and songs are fetched over a single command connection,
    /// reusing whichever of them is already loaded for the active category.
    /// Artists and their album counts are derived from the albums, the same
    /// way the artist list itself is, so they cost no further round trip.
    ///
    /// - Throws: An error if the MPD connection fails or the fetch is
    ///           cancelled.
    func prepareSearch() async throws {
        guard library == nil else {
            return
        }

        if let preparation {
            return try await preparation.value
        }

        let loadedAlbums: [Album]?
        let loadedSongs: [Song]?

        switch media {
        case let .albums(albums):
            loadedAlbums = albums
            loadedSongs = nil
        case let .songs(songs):
            loadedAlbums = nil
            loadedSongs = songs
        case .artists, nil:
            loadedAlbums = nil
            loadedSongs = nil
        }

        let preparation = Task<Void, any Error> {
            let loaded = try await ConnectionManager.command { connection in
                let albums = try await DatabaseManager.reuse(loadedAlbums) {
                    try await connection.getAlbums()
                }
                let songs = try await DatabaseManager.reuse(loadedSongs) {
                    try await connection.getSongs(from: Source.database)
                }

                var artistAlbumCounts: [String: Int] = [:]
                var seen: Set<String> = []
                var artists: [Artist] = []

                for album in albums {
                    artistAlbumCounts[album.artist.id, default: 0] += 1

                    if seen.insert(album.artist.id).inserted {
                        artists.append(album.artist)
                    }
                }

                return Library(artists: artists, albums: albums, songs: songs,
                               artistAlbumCounts: artistAlbumCounts)
            }

            library = loaded
        }

        self.preparation = preparation

        defer { self.preparation = nil }

        try await preparation.value
    }

    /// Searches the entire library on a background thread, matching artists,
    /// albums, and songs in one pass.
    ///
    /// Each media type is matched against its own search fields, so the song
    /// specific fields (genre, composer, and so on) don't affect albums or
    /// artists. Call `prepareSearch()` first; until it completes the results
    /// are empty.
    ///
    /// - Parameters:
    ///   - query: The search query string.
    ///   - artistFields: The fields to match artists against.
    ///   - albumFields: The fields to match albums against.
    ///   - songFields: The fields to match songs against.
    /// - Returns: The matching media, closest matches first within each type.
    func searchLibrary(_ query: String, artistFields: SearchFields,
                       albumFields: SearchFields, songFields: SearchFields)
        async -> SearchResults
    {
        guard !query.isEmpty, let library else {
            return .empty
        }

        let artistFields = artistFields.fields
        let albumFields = albumFields.fields
        let songFields = songFields.fields
        let folded = query.folded

        return await Task { @concurrent in
            SearchResults(
                artists: rank(library.artists.filter {
                    matches($0, query: folded, fields: artistFields)
                }, for: folded),
                albums: rank(library.albums.filter {
                    matches($0, query: folded, fields: albumFields)
                }, for: folded),
                songs: rank(library.songs.filter {
                    matches($0, query: folded, fields: songFields)
                }, for: folded),
                artistAlbumCounts: library.artistAlbumCounts,
            )
        }.value
    }

    /// Returns the already-loaded collection when it is the one wanted, and
    /// fetches it from the server otherwise.
    ///
    /// - Parameters:
    ///   - loaded: The collection already in memory, if it is of the wanted
    ///             type.
    ///   - fetch: Fetches the collection from the server.
    /// - Returns: The collection to search through.
    private nonisolated static func reuse<T>(_ loaded: [T]?,
                                             _ fetch: () async throws -> [T])
        async rethrows -> [T]
    {
        guard let loaded else {
            return try await fetch()
        }

        return loaded
    }

    /// Orders matches by how closely they match the query: an exact name
    /// first, then names starting with the query, then the rest, with each
    /// group keeping the library's own order.
    ///
    /// - Parameters:
    ///   - items: The media items that matched the query.
    ///   - query: The folded search query string.
    /// - Returns: The items ordered by how closely they match.
    private nonisolated func rank<T: Nameable>(_ items: [T], for query: String)
        -> [T]
    {
        let scored: [(offset: Int, item: T, score: Int)] = items.enumerated()
            .map { (offset: $0.offset, item: $0.element, score: score($0.element, for: query)) }

        return scored
            .sorted { $0.score == $1.score ? $0.offset < $1.offset : $0.score < $1.score }
            .map(\.item)
    }

    /// Scores how closely a media item's name matches a folded query, lower
    /// being closer.
    ///
    /// - Parameters:
    ///   - item: The media item to score.
    ///   - query: The folded search query string.
    /// - Returns: `0` for an exact name, `1` for a name starting with the
    ///            query, `2` otherwise.
    private nonisolated func score(_ item: some Nameable, for query: String)
        -> Int
    {
        let name = item.displayName.folded

        if name == query {
            return 0
        }

        return name.hasPrefix(query) ? 1 : 2
    }
}
