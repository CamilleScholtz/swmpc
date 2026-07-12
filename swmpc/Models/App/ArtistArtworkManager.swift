//
//  ArtistArtworkManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 12/07/2026.
//

import Foundation
import MPDKit
import MusicKit

/// Catalog metadata for an artist: artwork URL, genres, and editorial notes.
nonisolated struct ArtistInfo: Codable, Equatable {
    let url: URL?
    let genres: [String]
    let bio: String?
}

/// Manages artist image and metadata lookups via the Apple Music catalog.
///
/// `ArtistArtworkManager` is a singleton actor that resolves an MPD artist
/// name to an `ArtistInfo` using `MusicCatalogSearchRequest`. MusicKit only
/// mints tokens once the user has granted music authorization, so the first
/// lookup triggers a one-time system permission prompt; when authorization
/// is denied, lookups quietly resolve to `nil`.
///
/// Resolved info (including misses, so unknown artists aren't re-queried
/// every launch) is persisted to disk and expires after 30 days. Image data
/// itself is cached by the HTTP layer, see `ArtistImageView`.
actor ArtistArtworkManager {
    static let shared = ArtistArtworkManager()

    /// A single name → info resolution, `info` is `nil` for a known miss.
    private nonisolated struct Entry: Codable {
        let info: ArtistInfo?
        let date: Date
    }

    /// Maps artist names to their resolved catalog info.
    private var entries: [String: Entry] = [:]

    /// Tracks in-flight lookups to deduplicate concurrent requests.
    private var tasks: [String: Task<ArtistInfo?, Never>] = [:]

    /// The tail of the request queue; each catalog request chains onto the
    /// previous one so lookups are spaced out, see `throttle()`.
    private var lastRequest: Task<Void, Never>?

    /// Thrown when a search returns no candidates at all, which is
    /// indistinguishable from a rate-limited response — so it must not be
    /// cached as a miss.
    private nonisolated struct EmptySearchResponse: Error {}

    /// Debounces disk writes while many rows resolve during scrolling.
    private var saveTask: Task<Void, Error>?

    private var isLoaded = false

    /// The pixel size requested from the artwork CDN. A single canonical size
    /// keeps the row and header views on the same cached image.
    private static let imageSize = 320

    /// Minimum spacing between catalog requests. Apple's rate limits are
    /// undocumented, but bursts (e.g. fast-scrolling a large artist list)
    /// trigger 429 "API capacity exceeded" responses.
    private static let requestSpacing: Duration = .milliseconds(150)

    /// Entries older than this are re-resolved, so artists that gain images
    /// later (or whose CDN URLs rot) recover eventually.
    private static let expiry: TimeInterval = 30 * 24 * 60 * 60

    /// The cache file, versioned so stale formats are discarded instead of
    /// partially decoding (an old entry could otherwise masquerade as a
    /// cached miss).
    private nonisolated static var cacheURL: URL {
        URL.applicationSupportDirectory.appending(path: "ArtistInfo-v2.json")
    }

    /// Cache files from older builds, removed on first load.
    private nonisolated static var staleCacheURLs: [URL] {
        [URL.applicationSupportDirectory.appending(path: "ArtistArtwork.json")]
    }

    private init() {}

    /// Resolves the Apple Music catalog info for a given artist, handling
    /// caching and request deduplication.
    ///
    /// - Parameter artist: The MPD artist to resolve info for.
    /// - Returns: The artist's catalog info, or `nil` if no confident match
    ///            exists or the lookup failed.
    func info(for artist: MPDKit.Artist) async -> ArtistInfo? {
        loadIfNeeded()

        if let entry = entries[artist.name],
           Date.now.timeIntervalSince(entry.date) < Self.expiry
        {
            return entry.info
        }

        guard await requestAuthorization() else {
            return nil
        }

        if let task = tasks[artist.name] {
            return await task.value
        }

        let task = Task {
            defer { tasks[artist.name] = nil }

            do {
                let info = try await search(for: artist.name)

                entries[artist.name] = Entry(info: info, date: .now)
                scheduleSave()

                return info
            } catch {
                // Transient failure: don't cache a miss, retry next launch.
                return nil
            }
        }
        tasks[artist.name] = task

        return await task.value
    }

    /// Ensures the app is authorized for MusicKit, prompting the user the
    /// first time. MusicKit refuses to mint even developer tokens while the
    /// authorization status is undetermined.
    private func requestAuthorization() async -> Bool {
        switch MusicAuthorization.currentStatus {
        case .authorized:
            true
        case .notDetermined:
            await MusicAuthorization.request() == .authorized
        default:
            false
        }
    }

    /// Waits for a slot in the request queue, spacing catalog requests out
    /// to stay under Apple's rate limits.
    private func throttle() async {
        let previous = lastRequest

        let task = Task {
            await previous?.value
            try? await Task.sleep(for: Self.requestSpacing)
        }
        lastRequest = task

        await task.value
    }

    /// Searches the Apple Music catalog for an artist and returns the info
    /// of the best match, or `nil` when no candidate matches confidently.
    ///
    /// - Throws: `EmptySearchResponse` when no term yields any candidates,
    ///           so the caller treats it as transient instead of caching a
    ///           miss; rate-limited responses come back empty.
    private func search(for name: String) async throws -> ArtistInfo? {
        var sawCandidates = false

        for term in Self.searchTerms(for: name) {
            await throttle()

            var request = MusicCatalogSearchRequest(
                term: term,
                types: [MusicKit.Artist.self],
            )
            request.limit = 5

            let response = try await request.response()

            guard !response.artists.isEmpty else {
                continue
            }
            sawCandidates = true

            let normalized = Self.normalize(term)
            guard let match = response.artists.first(where: {
                Self.normalize($0.name) == normalized
            }) else {
                continue
            }

            return ArtistInfo(
                url: match.artwork?.url(
                    width: Self.imageSize,
                    height: Self.imageSize,
                ),
                genres: (match.genreNames ?? []).filter { $0 != "Music" },
                bio: match.editorialNotes?.standard ?? match.editorialNotes?.short,
            )
        }

        guard sawCandidates else {
            throw EmptySearchResponse()
        }

        return nil
    }

    /// Builds the search terms to try, in order: the full name, then the
    /// primary artist with any "feat."-style suffix removed.
    private nonisolated static func searchTerms(for name: String) -> [String] {
        var terms = [name]

        for separator in [" feat. ", " feat ", " ft. ", " featuring "] {
            if let range = name.range(of: separator, options: .caseInsensitive) {
                let primary = String(name[..<range.lowerBound])
                    .trimmingCharacters(in: .whitespaces)

                if !primary.isEmpty {
                    terms.append(primary)
                }

                break
            }
        }

        return terms
    }

    /// Normalizes an artist name for comparison: case- and diacritic-folded,
    /// leading "The" dropped, and punctuation removed. A wrong match is worse
    /// than no match, so comparisons stay exact after normalization.
    private nonisolated static func normalize(_ name: String) -> String {
        var result = name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)

        if result.hasPrefix("the ") {
            result.removeFirst(4)
        }

        return result.filter { $0.isLetter || $0.isNumber }
    }

    private func loadIfNeeded() {
        guard !isLoaded else {
            return
        }
        isLoaded = true

        for url in Self.staleCacheURLs {
            try? FileManager.default.removeItem(at: url)
        }

        guard let data = try? Data(contentsOf: Self.cacheURL) else {
            return
        }

        entries = (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }

    private func scheduleSave() {
        saveTask?.cancel()

        saveTask = Task {
            try await Task.sleep(for: .seconds(1))

            let data = try JSONEncoder().encode(entries)

            try FileManager.default.createDirectory(
                at: Self.cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try data.write(to: Self.cacheURL, options: .atomic)
        }
    }
}
