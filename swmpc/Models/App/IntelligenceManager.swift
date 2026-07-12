//
//  IntelligenceManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/03/2025.
//

import AnyLanguageModel
import Foundation
import MPDKit
import SFSafeSymbols

/// Errors that can occur during intelligence operations.
enum IntelligenceManagerError: LocalizedError {
    /// The provider's API token is missing.
    case missingToken
    /// The provider is misconfigured (e.g. an invalid custom base URL).
    case invalidConfiguration
    /// Apple Intelligence is not available on this device.
    case appleIntelligenceUnavailable
    /// The operation timed out.
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "API token missing: Add a token in Settings"
        case .invalidConfiguration:
            "Invalid provider configuration: Check the base URL in Settings"
        case .appleIntelligenceUnavailable:
            "Apple Intelligence unavailable: Enable Apple Intelligence or select a provider in Settings"
        case .timeout:
            "Request timed out: Try again or check network connection"
        }
    }
}

/// Target destination for intelligence-generated songs.
enum IntelligenceTarget: Identifiable {
    /// Add songs to a specific playlist.
    case playlist(Playlist)
    /// Add songs directly to the playback queue.
    case queue

    var id: String {
        switch self {
        case let .playlist(playlist): "playlist-\(playlist.name)"
        case .queue: "queue"
        }
    }
}

/// Available AI providers for generating playlists.
///
/// Apple Intelligence (the default) talks to Private Cloud Compute directly
/// through the FoundationModels framework and needs no API token. Every other
/// provider is routed through the `LanguageModel` protocol of the
/// AnyLanguageModel package. Native model types are used for OpenAI,
/// Anthropic, and Gemini; the OpenAI-compatible model (with a custom base
/// URL) backs Grok, OpenRouter, and custom endpoints.
nonisolated enum IntelligenceProvider: String, Identifiable, CaseIterable {
    case apple
    case openAI = "openai"
    case anthropic
    case gemini
    case openRouter = "openrouter"
    case grok
    case custom

    var id: String {
        rawValue
    }

    /// Display name for the provider.
    var name: String {
        switch self {
        case .apple: "Apple Intelligence"
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        case .openRouter: "OpenRouter"
        case .grok: "Grok"
        case .custom: "Custom"
        }
    }

    /// Fallback model identifier when the user has not selected one.
    var defaultModel: String {
        switch self {
        case .apple: ""
        case .openAI: "gpt-5-mini"
        case .anthropic: "claude-haiku-4-5"
        case .gemini: "gemini-2.5-flash-lite"
        case .openRouter: "openai/gpt-5-mini"
        case .grok: "grok-4-1-fast-non-reasoning"
        case .custom: ""
        }
    }

    /// Keychain account for storing the API token.
    var tokenKey: String {
        "\(rawValue)_token"
    }

    /// UserDefaults key for storing the user-selected model identifier.
    var modelKey: String {
        "\(rawValue)_model"
    }

    /// The stored API token, or an empty string when none is set.
    ///
    /// Tokens live in the Keychain. A token written to UserDefaults by an
    /// earlier version is migrated to the Keychain on first read.
    var token: String {
        if let stored = Keychain.string(for: tokenKey) {
            return stored
        }

        if let legacy = UserDefaults.standard.string(forKey: tokenKey), !legacy.isEmpty {
            Keychain.set(legacy, for: tokenKey)
            UserDefaults.standard.removeObject(forKey: tokenKey)

            return legacy
        }

        return ""
    }

    /// The user-selected model identifier, or the default if none is set.
    var selectedModel: String {
        let stored = UserDefaults.standard.string(forKey: modelKey) ?? ""
        return stored.isEmpty ? defaultModel : stored
    }

    /// Base URL for OpenAI-compatible providers, or `nil` when not applicable.
    private var baseURL: URL? {
        switch self {
        case .grok:
            URL(string: "https://api.x.ai/v1")
        case .openRouter:
            URL(string: "https://openrouter.ai/api/v1")
        case .custom:
            Self.customBaseURL
        default:
            nil
        }
    }

    /// Parses the user-provided custom host into a base URL.
    private static var customBaseURL: URL? {
        let raw = (UserDefaults.standard.string(forKey: Setting.customHost) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return nil
        }

        return URL(string: raw.contains("://") ? raw : "http://\(raw)")
    }

    /// Builds the AnyLanguageModel model for this provider.
    ///
    /// Apple Intelligence is not backed by AnyLanguageModel; it is handled
    /// directly by `PrivateCloudCompute` instead.
    ///
    /// - Returns: A configured `LanguageModel` instance.
    /// - Throws: `IntelligenceManagerError.invalidConfiguration` for a bad
    ///           custom URL.
    func makeModel() throws -> any LanguageModel {
        let key = token

        switch self {
        case .apple:
            throw IntelligenceManagerError.invalidConfiguration
        case .openAI:
            return OpenAILanguageModel(apiKey: key, model: selectedModel)
        case .anthropic:
            return AnthropicLanguageModel(apiKey: key, model: selectedModel)
        case .gemini:
            return GeminiLanguageModel(apiKey: key, model: selectedModel)
        case .grok, .openRouter, .custom:
            guard let url = baseURL else {
                throw IntelligenceManagerError.invalidConfiguration
            }

            return OpenAILanguageModel(baseURL: url, apiKey: key, model: selectedModel)
        }
    }
}

/// Response structure for AI-generated playlists.
/// Marked as nonisolated so guided generation can run off the main actor.
@Generable
nonisolated struct IntelligenceResponse {
    /// Array of album names in "Artist - Album" format.
    @Guide(description: "Album names in 'Artist - Album' format, selected from the user's provided list")
    var playlist: [String]
}

/// Generates AI-powered playlists using a configurable model provider.
///
/// The feature is stateless, so it lives as a namespace rather than an
/// instance.
nonisolated enum IntelligenceManager {
    /// Maximum number of albums to send to the model in a single request.
    private static let albumLimit = 1000

    /// System instructions given to every provider.
    private static let instructions = """
    You are an expert music curator with comprehensive knowledge of artists, albums, genres, and styles across all eras and popularity levels.

    <task>
    Analyze the user's playlist description and select matching albums from their provided list. Return only albums that appear in the user's list.
    </task>

    <input_format>
    The user will provide:
    1. A playlist description (theme, mood, genre, era, or other criteria)
    2. A list of available albums formatted as `[artist] - [title]`
    </input_format>

    <selection_guidelines>
    - Select 5-20 albums depending on request specificity
    - Prioritize strong matches over weak connections
    - For broad requests (e.g., "best albums"): select diverse, highly-regarded works
    - For specific requests (e.g., "ambient electronic from the 90s"): focus tightly on criteria
    - Balance variety with coherence unless the description requires otherwise
    </selection_guidelines>
    """

    /// The currently selected provider, defaulting to Apple Intelligence.
    static var currentProvider: IntelligenceProvider {
        UserDefaults.standard.string(forKey: Setting.intelligenceModel)
            .flatMap { IntelligenceProvider(rawValue: $0) } ?? .apple
    }

    /// Symbol representing the current provider in AI-related controls.
    static var symbol: SFSymbol {
        currentProvider == .apple ? .siri : .sparkles
    }

    /// Whether the selected provider is configured and usable. This is the
    /// sole gate for AI features — Apple Intelligence just needs to be
    /// available on the device; any other provider needs a token (or a custom
    /// endpoint).
    static var isEnabled: Bool {
        switch currentProvider {
        case .apple:
            PrivateCloudCompute.isAvailable
        case .custom:
            true
        default:
            !currentProvider.token.isEmpty
        }
    }

    /// Generates a playlist based on a prompt and adds songs to the specified
    /// target.
    ///
    /// - Parameters:
    ///   - target: Destination for generated songs (playlist or queue).
    ///   - prompt: Natural language description of desired playlist.
    /// - Throws: `IntelligenceManagerError.timeout` if operation exceeds 30
    ///           seconds, an error if the provider is disabled or
    ///           misconfigured, or connection/command/generation errors.
    static func fill(target: IntelligenceTarget, prompt: String) async throws {
        try await withTimeout(seconds: 30) {
            let provider = currentProvider

            guard isEnabled else {
                throw provider == .apple
                    ? IntelligenceManagerError.appleIntelligenceUnavailable
                    : IntelligenceManagerError.missingToken
            }

            let albums = try await ConnectionManager.command { manager in
                if case .playlist = target {
                    try await manager.loadPlaylist()
                }

                return try await manager.getAlbums()
            }

            // Only sample randomly when the full library is too large to fit.
            let selectedAlbums = albums.count > albumLimit
                ? Array(albums.shuffled().prefix(albumLimit))
                : albums
            let albumDescriptions = selectedAlbums.map(\.description).joined(separator: "\n")

            let userPrompt = """
            <playlist_description>
            \(prompt)
            </playlist_description>

            <available_albums>
            \(albumDescriptions)
            </available_albums>
            """

            let playlist: [String]
            if provider == .apple {
                playlist = try await PrivateCloudCompute.generatePlaylist(
                    instructions: instructions,
                    prompt: userPrompt,
                )
            } else {
                let session = try LanguageModelSession(
                    model: provider.makeModel(),
                    instructions: instructions,
                )
                let response = try await session.respond(
                    to: userPrompt,
                    generating: IntelligenceResponse.self,
                )

                playlist = response.content.playlist
            }

            let songs = try await collectSongs(from: playlist, albums: albums)

            try await addSongs(songs, to: target)
        }
    }

    /// Collects songs from album names in the AI response.
    ///
    /// - Parameters:
    ///   - playlist: Array of album names in "Artist - Album" format.
    ///   - albums: Available albums from MPD library.
    /// - Returns: Array of songs from matched albums.
    /// - Throws: Errors from fetching album songs.
    private static func collectSongs(from playlist: [String], albums: [Album]) async
        throws -> [Song]
    {
        var songs: [Song] = []

        for albumName in playlist {
            guard let album = albums.first(where: { $0.description ==
                    albumName
            }) else {
                continue
            }

            try await songs.append(contentsOf: album.getSongs())
        }

        return songs
    }

    /// Adds collected songs to the specified target destination.
    ///
    /// - Parameters:
    ///   - songs: Songs to add.
    ///   - target: Destination (playlist or queue).
    /// - Throws: Errors from MPD command operations.
    private static func addSongs(_ songs: [Song], to target: IntelligenceTarget) async throws {
        switch target {
        case let .playlist(playlist):
            try await ConnectionManager.command { manager in
                try await manager.add(songs: songs, to: .playlist(playlist))
                try await manager.loadPlaylist(playlist)
            }
        case .queue:
            try await ConnectionManager.command {
                try await $0.add(songs: songs, to: .queue)
            }
        }
    }

    /// Executes an async operation with a timeout.
    ///
    /// - Parameters:
    ///   - seconds: Maximum time to wait before cancelling.
    ///   - operation: The async operation to execute.
    /// - Returns: Result from the operation if completed within timeout.
    /// - Throws: `IntelligenceManagerError.timeout` if operation exceeds time
    ///           limit, or any error thrown by the operation itself.
    private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw IntelligenceManagerError.timeout
            }

            guard let result = try await group.next() else {
                throw IntelligenceManagerError.timeout
            }

            group.cancelAll()

            return result
        }
    }
}
