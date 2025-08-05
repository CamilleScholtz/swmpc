//
//  DatabaseManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

/// Manages the MPD database, handling artists, albums, and song queries.
@Observable final class DatabaseManager {
    /// The loading state manager, used to indicate when data is being fetched.
    private let state: LoadingState

    /// Creates a new database manager.
    ///
    /// - Parameter state: An instance of `LoadingState` to report back loading
    ///                    activity for UI updates.
    init(state: LoadingState) {
        self.state = state
    }

    /// The collection of currently loaded media items (e.g., albums, artists,
    /// or songs) based on the active `type`.
    private(set) var media: [any Mediable]?

    /// The current type of media being displayed or managed (e.g., albums, artists).
    private(set) var type: MediaType = .album

    /// The current sort option being used.
    private(set) var sort: SortDescriptor = .init(option: .artist)

    /// Sets the media type and reloads the media data from the server.
    ///
    /// This method updates the `type` property and then calls `fetchMedia` to
    /// repopulate the `media` collection. It can be forced to reload even if
    /// the media type has not changed.
    ///
    /// - Parameters:
    ///   - type: The new media type to set. If nil, uses the current type.
    ///   - sort: The new sort descriptor to use. If nil, uses the current sort.
    ///   - idle: A Boolean indicating whether to use the long-lived idle
    ///           connection for the fetch, which is more efficient.
    /// - Throws: An error if fetching the media from the server fails.
    func set(idle: Bool = true, type: MediaType? = nil, sort: SortDescriptor?
        = nil)
        async throws
    {
        defer { state.isLoading = false }

        guard type != self.type || sort != self.sort else {
            return
        }

        let newMedia: [any Mediable]? = switch type ?? self.type {
        case .album:
            try await idle
                ? ConnectionManager.idle.getAlbums(sort: sort ?? self.sort)
                : ConnectionManager.command().getAlbums(sort: sort ?? self.sort)
        case .artist:
            try await idle
                ? ConnectionManager.idle.getArtists(sort: sort ?? self.sort)
                : ConnectionManager.command().getArtists(sort: sort ?? self.sort)
        case .song:
            try await idle
                ? ConnectionManager.idle.getSongs(from: Source.database,
                                                  sort: sort ?? self.sort)
                : ConnectionManager.command().getSongs(from: Source.database,
                                                       sort: sort ?? self.sort)
        case .playlist:
            nil
        }

        try Task.checkCancellation()

        if let type {
            self.type = type
        }
        if let sort {
            self.sort = sort
        }

        media = newMedia
    }

    /// Searches through the locally cached media library in parallel.
    ///
    /// This function performs a case-insensitive search through the already fetched media,
    /// matching the query against fields determined by the search fields. It parallelizes
    /// the search by dividing the media collection into chunks and processing them concurrently.
    ///
    /// - Parameters:
    ///   - query: The search query string to match against the selected fields.
    ///   - fields: The search fields that determine which fields to search.
    /// - Returns: An array of media items matching the search criteria.
    func search(query: String, fields: SearchFields) async -> [any Mediable] {
        guard !query.isEmpty, !fields.isEmpty, let media else {
            return []
        }

        let lowercasedQuery = query.lowercased()
        let searchFields = fields.fields

        return await withTaskGroup(of: [any Mediable].self) { group in
            // Divide the media array into chunks to be processed in parallel.
            // The number of chunks is based on the number of active processor cores.
            let chunks = media.chunked(into: max(1, media.count / ProcessInfo.processInfo.activeProcessorCount))

            for chunk in chunks {
                group.addTask {
                    chunk.filter { item in
                        // By switching on the item's type first, we avoid redundant type-casting.
                        switch item {
                        case let song as Song:
                            // Use short-circuiting boolean logic for efficient checking.
                            (searchFields.contains("title") && song.title.lowercased().contains(lowercasedQuery)) ||
                                (searchFields.contains("artist") && song.artist.lowercased().contains(lowercasedQuery)) ||
                                (searchFields.contains("album") && song.album.title.lowercased().contains(lowercasedQuery))

                        case let album as Album:
                            (searchFields.contains("title") && album.title.lowercased().contains(lowercasedQuery)) ||
                                (searchFields.contains("artist") && album.artist.name.lowercased().contains(lowercasedQuery))

                        case let artist as Artist:
                            searchFields.contains("artist") && artist.name.lowercased().contains(lowercasedQuery)

                        default:
                            // If the item is not a known type, it cannot match.
                            false
                        }
                    }
                }
            }

            var results: [any Mediable] = []
            for await chunkResults in group {
                results.append(contentsOf: chunkResults)
            }
            return results
        }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
