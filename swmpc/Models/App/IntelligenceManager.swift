//
//  IntelligenceManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/03/2025.
//

import OpenAI
import SwiftUI

/// Errors that can occur during intelligence operations.
enum IntelligenceManagerError: LocalizedError {
    /// Intelligence feature is disabled in settings.
    case intelligenceDisabled
    /// API token is missing or empty.
    case missingToken
    /// No response was received from the API.
    case noResponse
    /// The operation timed out.
    case timeout

    var errorDescription: String? {
        switch self {
        case .intelligenceDisabled:
            "AI features are disabled: Enable in settings"
        case .missingToken:
            "API token missing: Add token in settings"
        case .noResponse:
            "No response received from AI service"
        case .timeout:
            "Request timed out: Try again or check network connection"
        }
    }
}

/// Target destination for intelligence-generated songs.
enum IntelligenceTarget {
    /// Add songs to a specific playlist.
    case playlist(Binding<Playlist?>)
    /// Add songs directly to the playback queue.
    case queue
}

/// Configuration for an AI model provider.
nonisolated struct ModelConfig {
    /// Display name for the model provider.
    let name: String
    /// Specific model identifier to use.
    let model: String
    /// API host URL.
    let host: String
    /// API base path.
    let path: String
    /// UserDefaults key for storing the API token.
    let setting: String
    /// Whether the model is enabled.
    let isEnabled: Bool
}

/// Available AI model providers for generating playlists.
nonisolated enum IntelligenceModel: String, Identifiable, CaseIterable {
    var id: String { rawValue }

    case openAI
    case deepSeek
    case gemini
    case grok
    case claude

    /// Model configurations for each provider.
    private static let configs: [IntelligenceModel: ModelConfig] = [
        .openAI: ModelConfig(
            name: "OpenAI",
            model: "gpt-5-mini",
            host: "api.openai.com",
            path: "/v1",
            setting: Setting.openAIToken,
            isEnabled: true,
        ),
        .deepSeek: ModelConfig(
            name: "DeepSeek",
            model: "deepseek-chat",
            host: "api.deepseek.com",
            path: "/v1",
            setting: Setting.deepSeekToken,
            isEnabled: true,
        ),
        .gemini: ModelConfig(
            name: "Gemini",
            model: "gemini-2.5-flash-lite",
            host: "generativelanguage.googleapis.com",
            path: "/v1beta/openai",
            setting: Setting.geminiToken,
            isEnabled: true,
        ),
        .grok: ModelConfig(
            name: "Grok",
            model: "grok-3-mini-latest",
            host: "api.x.ai",
            path: "/v1",
            setting: Setting.grokToken,
            isEnabled: true,
        ),
        .claude: ModelConfig(
            name: "Claude",
            model: "claude-haiku-4-5",
            host: "api.anthropic.com",
            path: "/v1",
            setting: Setting.claudeToken,
            isEnabled: true,
        ),
    ]

    /// Retrieves the configuration for this model.
    private var config: ModelConfig {
        guard let config = Self.configs[self] else {
            fatalError(
                "Missing configuration for IntelligenceModel case: \(self)")
        }

        return config
    }

    /// Display name for the model provider.
    var name: String { config.name }
    /// Specific model identifier to use.
    var model: String { config.model }
    /// API host URL.
    var host: String { config.host }
    /// API base path.
    var path: String { config.path }
    /// UserDefaults key for storing the API token.
    var setting: String { config.setting }
    /// Whether the model supports structured output.
    var isEnabled: Bool { config.isEnabled }
}

/// Response structure for AI-generated playlists.
/// Marked as nonisolated to allow JSON encoding/decoding on background threads.
nonisolated struct IntelligenceResponse: JSONSchemaConvertible {
    /// Array of album names in "Artist - Album" format.
    let playlist: [String]

    /// Example response for schema generation.
    static let example: Self = .init(playlist: [
        "Philip Glass - Koyaanisqatsi",
        "Philip Glass - Einstein on the Beach",
        "Steve Reich - Music for 18 Musicians",
    ])
}

/// Manages AI-powered playlist generation using various model providers. Uses
/// an actor to ensure thread-safe access to API operations.
actor IntelligenceManager {
    /// Shared singleton instance.
    static let shared = IntelligenceManager()

    private init() {}

    /// Checks if intelligence mode is enabled (setting enabled and token not
    /// empty).
    static var isEnabled: Bool {
        let settingEnabled = UserDefaults.standard.bool(forKey: Setting
            .isIntelligenceEnabled)
        let model = UserDefaults.standard.string(forKey: Setting
            .intelligenceModel)
            .flatMap { IntelligenceModel(rawValue: $0) } ?? .openAI
        let token = UserDefaults.standard.string(forKey: model.setting) ?? ""

        return settingEnabled && !token.isEmpty
    }

    /// Creates an OpenAI client configured for the specified model provider.
    ///
    /// - Parameter model: The AI model provider to connect to.
    /// - Returns: Configured OpenAI client instance.
    /// - Throws: `IntelligenceManagerError.intelligenceDisabled` if
    ///           intelligence is disabled,
    ///           `IntelligenceManagerError.missingToken` if API token is not
    ///           configured.
    private func connect(using model: IntelligenceModel) throws -> OpenAI {
        guard Self.isEnabled else {
            throw IntelligenceManagerError.intelligenceDisabled
        }

        return OpenAI(configuration: OpenAI.Configuration(
            token: UserDefaults.standard.string(forKey: model.setting) ?? "",
            host: model.host,
            basePath: model.path,
            parsingOptions: .fillRequiredFieldIfKeyNotFound,
        ))
    }

    /// Generates a playlist based on a prompt and adds songs to the specified
    /// target.
    ///
    /// - Parameters:
    ///   - target: Destination for generated songs (playlist or queue).
    ///   - prompt: Natural language description of desired playlist.
    /// - Throws: `IntelligenceManagerError.timeout` if operation exceeds 30
    ///           seconds, `IntelligenceManagerError.noResponse` if API returns
    ///           invalid response, or connection/command errors.
    func fill(target: IntelligenceTarget, prompt: String) async throws {
        try await withTimeout(seconds: 30) {
            let model = await MainActor.run {
                UserDefaults.standard.string(forKey: Setting.intelligenceModel)
                    .flatMap { IntelligenceModel(rawValue: $0) } ?? .openAI
            }

            let client = try await self.connect(using: model)

            let albums = try await ConnectionManager.command { manager in
                if case .playlist = target {
                    try await manager.loadPlaylist()
                }

                return try await manager.getAlbums()
            }

            let selectedAlbums = albums.count > 1000
                ? Array(albums.shuffled().prefix(1000))
                : albums
            let albumDescriptions = selectedAlbums.map(\.description).joined(
                separator: "\n")

            let prefill = """
            {
              "playlist": [
            """

            let result = try await client.chats(query: ChatQuery(
                messages: [
                    .init(role: .system, content: """
                    You are an expert music curator with comprehensive knowledge of artists, albums, genres, and styles across all eras and popularity levels.

                    Your task is to analyze the playlist description below and select albums from the list provided by the user that best match the request.

                    ## SELECTION CRITERIA

                    - Only select albums that appear in the user's provided list
                    - Match albums based on genre, mood, era, style, theme, or other relevant criteria
                    - Prioritize strong matches over weak connections
                    - Include 5-20 albums depending on the specificity of the request
                    - Balance variety with coherence unless the description requires otherwise
                    - If the description is broad (e.g., "best albums"), select diverse, highly-regarded works
                    - If the description is specific (e.g., "ambient electronic from the 90s"), focus tightly on the criteria

                    ## INPUT

                    The user will send you a list of available albums in the format `[artist] - [title]`.

                    ## OUTPUT

                    You must respond with valid JSON matching this exact structure (example albums used):

                    {
                      "playlist": [
                        "Philip Glass - Koyaanisqatsi",
                        "Philip Glass - Einstein on the Beach",
                        "Steve Reich - Music for 18 Musicians"
                      ]
                    }

                    ## PLAYLIST DESCRIPTION

                    \(prompt)
                    """)!,
                    .init(role: .user, content: albumDescriptions)!,
                    .init(role: .assistant, content: prefill)!,
                ],
                model: model.model,
                responseFormat: .jsonObject,
            ))

            guard let content = result.choices.first?.message.content else {
                throw IntelligenceManagerError.noResponse
            }

            guard let data = (prefill + content).data(using: .utf8) else {
                throw IntelligenceManagerError.noResponse
            }

            let response = try JSONDecoder().decode(IntelligenceResponse.self,
                                                    from: data)

            let songs = try await self.collectSongs(from: response.playlist,
                                                    albums: albums)

            try await self.addSongs(songs, to: target)
        }
    }

    /// Collects songs from album names in the AI response.
    ///
    /// - Parameters:
    ///   - playlist: Array of album names in "Artist - Album" format.
    ///   - albums: Available albums from MPD library.
    /// - Returns: Array of songs from matched albums.
    /// - Throws: Errors from fetching album songs.
    private func collectSongs(from playlist: [String], albums: [Album]) async
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
    private func addSongs(_ songs: [Song], to target: IntelligenceTarget) async throws {
        switch target {
        case let .playlist(playlist):
            guard let playlist = playlist.wrappedValue else {
                return
            }

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
    private func withTimeout<T: Sendable>(
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
