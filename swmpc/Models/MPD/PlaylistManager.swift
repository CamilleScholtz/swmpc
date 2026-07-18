//
//  PlaylistManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 20/06/2025.
//

import Foundation
import FoundationModels
import MPDKit
import Observation
import SFSafeSymbols

/// Response structure for playlist symbol assignment.
///
/// Lives in this file — which does not import AnyLanguageModel — so the
/// FoundationModels `@Generable` macro does not clash with the
/// AnyLanguageModel macro of the same name.
@Generable
private nonisolated struct PlaylistSymbolResponse {
    @Guide(description: "The SF Symbol that best fits the playlist name", .anyOf(PlaylistSymbolCandidates.valid))
    var symbol: String
}

/// Curated SF Symbols the model is allowed to assign to playlists.
///
/// Symbols the app already uses elsewhere (categories, favorites, controls)
/// are deliberately absent so a playlist icon never mimics another UI element.
private nonisolated enum PlaylistSymbolCandidates {
    static let names: [String] = [
        // Music
        "music.quarternote.3", "guitars", "pianokeys", "headphones",
        "earbuds", "hifispeaker", "speaker.wave.3", "radio", "recordingtape",
        "metronome", "tuningfork", "amplifier", "horn",

        // Moods and weather
        "star", "bolt", "rainbow", "sun.max", "sunrise", "sunset",
        "sun.haze", "cloud.sun", "moon", "moon.stars", "cloud.rain",
        "cloud.bolt.rain", "snowflake", "wind", "tornado", "hurricane",
        "drop", "water.waves",

        // Nature
        "leaf", "tree", "mountain.2", "beach.umbrella", "pawprint", "bird",
        "fish", "ant", "ladybug", "hare", "tortoise", "cat", "dog", "carrot",

        // Activities and games
        "figure.run", "figure.walk", "figure.hiking", "figure.dance",
        "figure.yoga", "figure.mind.and.body", "figure.pool.swim", "dumbbell",
        "bicycle", "soccerball", "basketball", "football", "sportscourt",
        "trophy", "medal", "flag.checkered", "gamecontroller", "die.face.5",
        "puzzlepiece",

        // Travel and places
        "car", "airplane", "sailboat", "ferry", "tram", "fuelpump",
        "road.lanes", "map", "suitcase", "tent", "binoculars",
        "signpost.right", "globe.americas", "globe.europe.africa",
        "globe.asia.australia", "globe.central.south.asia", "building.2",

        // Occasions and entertainment
        "party.popper", "balloon.2", "fireworks", "gift", "birthday.cake",
        "crown", "theatermasks", "popcorn", "movieclapper", "film", "tv",

        // Food and drink
        "fork.knife", "cup.and.saucer", "wineglass", "mug",
        "takeoutbag.and.cup.and.straw",

        // Rest
        "zzz", "moon.zzz", "bed.double", "powersleep", "sofa", "fireplace",
        "lamp.desk",

        // Work and study
        "book", "books.vertical", "graduationcap", "brain", "lightbulb",
        "paintbrush", "paintpalette", "camera", "photo", "laptopcomputer",
        "desktopcomputer", "keyboard", "briefcase", "hammer",
        "wrench.and.screwdriver", "terminal",
        "chevron.left.forwardslash.chevron.right", "atom", "function",

        // Miscellaneous
        "hands.clap", "hand.thumbsup", "peacesign", "building.columns",
        "hourglass", "infinity", "eye", "shield", "target", "diamond",
    ]

    /// Candidates that exist in the SF Symbols catalog on the current OS.
    static let valid: [String] = names.filter {
        SFSymbol.allSymbols.contains(SFSymbol(rawValue: $0))
    }
}

/// Manages playlist operations for the MPD client.
@Observable final class PlaylistManager {
    /// The state manager, used to indicate when data is being fetched.
    @ObservationIgnored private let state: StateManager

    /// Cached symbol raw values keyed by playlist name, persisted so each
    /// name is only classified once across launches.
    @ObservationIgnored private var symbolCache: [String: String]

    /// Playlist names currently being classified.
    @ObservationIgnored private var symbolsInFlight: Set<String> = []

    private static let symbolCacheKey = "playlist_symbols_v2"

    private static let symbolInstructions = """
    You assign an icon to a music playlist based on its name. Pick the single SF Symbol that best captures the most distinctive aspect of the name: a genre, language or country, city, mood, activity, season, or time of day.

    Guidelines:
    - Prefer a specific, evocative match over a generic or merely music-related one.
    - For a country, language, or regional playlist, pick a globe for that region, or a landscape, nature, or travel symbol that evokes the place.
    - For city, urban, or nightlife themes, pick buildings, a car, or the moon.
    - Only pick an instrument when the name implies that instrument's sound: "guitars" fits rock or flamenco, "pianokeys" fits classical or jazz. Never pick an instrument for a language, country, or place.
    - Pick "music.quarternote.3" only as a last resort when nothing else fits.

    Examples:
    - Workout → dumbbell
    - Japanese → globe.asia.australia
    - Rainy Mood → cloud.rain
    - Citypop → building.2
    - Classical → building.columns
    - Road Trip → car
    - Christmas → snowflake
    """

    init(state: StateManager) {
        self.state = state
        symbolCache = UserDefaults.standard.dictionary(forKey: Self.symbolCacheKey)
            as? [String: String] ?? [:]

        // Drop the v1 cache; it was generated with a prompt that collapsed
        // onto the same symbol for most names.
        UserDefaults.standard.removeObject(forKey: "playlist_symbols")
    }

    /// The playlists available on the server.
    private(set) var playlists: [Playlist]?

    /// The songs in the `Favorites` playlist.
    private(set) var favorites: [Song] = []

    /// This asynchronous function sets the playlists available on the server.
    /// It also sets the songs in the `Favorites` playlist, attaches each
    /// playlist's symbol, and generates symbols for playlists that lack one.
    ///
    /// - Note: The `Favorites` playlist is filtered out of the playlists.
    ///
    /// - Throws: An error if the playlists could not be set.
    func set(idle: Bool = true) async throws {
        let (allPlaylists, favorites) = try await fetchPlaylists(idle: idle)

        playlists = allPlaylists.filter { $0.name != "Favorites" }.map {
            Playlist(name: $0.name, symbolName: symbolCache[$0.name])
        }
        self.favorites = favorites

        Task {
            await assignSymbols()
        }
    }

    /// Fetches the playlists from the MPD server.
    ///
    /// - Parameter idle: Whether to use the idle connection.
    /// - Returns: A tuple containing the playlists and the songs in the
    ///            `Favorites` playlist.
    private func fetchPlaylists(idle: Bool) async throws -> ([Playlist], [Song]) {
        let allPlaylists = try await idle
            ? ConnectionManager.idle.getPlaylists()
            : ConnectionManager.command {
                try await $0.getPlaylists()
            }

        guard let favoritePlaylist = allPlaylists.first(where: {
            $0.name == "Favorites"
        }) else {
            return (allPlaylists, [])
        }

        let favorites = try await idle
            ? ConnectionManager.idle.getSongs(from: .playlist(favoritePlaylist))
            : ConnectionManager.command {
                try await $0.getSongs(from: .playlist(favoritePlaylist))
            }

        return (allPlaylists, favorites)
    }

    /// Gets songs for a specific playlist.
    func getSongs(for playlist: Playlist) async throws -> [Song] {
        defer { state.isLoading = false }

        return try await ConnectionManager.command {
            try await $0.getSongs(from: .playlist(playlist))
        }
    }

    /// Generates and caches symbols for any playlists that lack one, using
    /// the on-device foundation model.
    ///
    /// Does nothing when Apple Intelligence is unavailable on this device;
    /// playlists then keep the generic fallback symbol. Failed generations
    /// are left uncached so they are retried on the next call. A renamed
    /// playlist naturally gets a fresh symbol for its new name.
    private func assignSymbols() async {
        guard SystemLanguageModel.default.isAvailable else {
            return
        }

        let pending = (playlists ?? []).map(\.name).filter {
            symbolCache[$0] == nil && !symbolsInFlight.contains($0)
        }
        guard !pending.isEmpty else {
            return
        }

        symbolsInFlight.formUnion(pending)
        defer { symbolsInFlight.subtract(pending) }

        for name in pending {
            let used = Set((playlists ?? []).compactMap(\.symbolName))

            guard let symbol = try? await Self.generateSymbol(for: name, avoiding: used) else {
                continue
            }

            symbolCache[name] = symbol
            UserDefaults.standard.set(symbolCache, forKey: Self.symbolCacheKey)

            if let index = playlists?.firstIndex(where: { $0.name == name }) {
                playlists?[index].symbolName = symbol
            }
        }
    }

    /// Asks the on-device model for the best-fitting symbol.
    ///
    /// Guided generation is constrained to `PlaylistSymbolCandidates.valid`,
    /// so the response is guaranteed to be a valid symbol name.
    ///
    /// - Parameters:
    ///   - name: The playlist name to classify.
    ///   - used: Symbols already assigned to other playlists, which the model
    ///           is nudged away from so every playlist gets a distinct icon.
    /// - Returns: The chosen SF Symbol raw value.
    /// - Throws: Generation or guardrail errors from FoundationModels.
    private static func generateSymbol(for name: String, avoiding used: Set<String>) async throws -> String {
        let session = LanguageModelSession(instructions: Instructions(symbolInstructions))

        var prompt = "Playlist name: \(name)"
        if !used.isEmpty {
            prompt += "\nAlready used by other playlists, avoid unless clearly the best fit: \(used.sorted().joined(separator: ", "))"
        }

        let response = try await session.respond(
            to: Prompt(prompt),
            generating: PlaylistSymbolResponse.self,
            options: GenerationOptions(samplingMode: .greedy),
        )

        return response.content.symbol
    }
}

extension Playlist {
    /// The SF Symbol shown for this playlist in the UI: a heart for
    /// Favorites, the assigned symbol, or the generic playlist symbol while
    /// none has been assigned yet.
    var symbol: SFSymbol {
        guard name != "Favorites" else {
            return .heart
        }

        guard let symbolName else {
            return .musicNoteList
        }

        return SFSymbol(rawValue: symbolName)
    }
}
