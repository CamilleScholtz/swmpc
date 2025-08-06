//
//  IntelligenceManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/03/2025.
//

import OpenAI
import SwiftUI

enum IntelligenceManagerError: Error {
    case intelligenceDisabled
    case missingToken
    case noResponse
    case timeout
}

enum IntelligenceTarget {
    case playlist(Binding<Playlist?>)
    case queue
}

struct ModelConfig {
    let name: String
    let model: String
    let host: String
    let path: String
    let setting: String
    let isEnabled: Bool
}

enum IntelligenceModel: String, Identifiable, CaseIterable {
    var id: String { rawValue }

    case openAI
    case deepSeek
    case gemini
    case grok
    case claude

    private static let configs: [IntelligenceModel: ModelConfig] = [
        .openAI: ModelConfig(
            name: "OpenAI",
            model: "gpt-4.1-mini",
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
            isEnabled: false, // NOTE: Doesn't support structured output
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
            model: "claude-3-5-haiku-latest",
            host: "api.anthropic.com",
            path: "/v1/messages",
            setting: Setting.claudeToken,
            isEnabled: true,
        ),
    ]

    private var config: ModelConfig {
        Self.configs[self]!
    }

    var name: String { config.name }
    var model: String { config.model }
    var host: String { config.host }
    var path: String { config.path }
    var setting: String { config.setting }
    var isEnabled: Bool { config.isEnabled }
}

nonisolated struct IntelligenceResponse: JSONSchemaConvertible {
    let playlist: [String]

    static let example: Self = .init(playlist: [
        "Philip Glass - Koyaanisqatsi",
        "Philip Glass - Glassworks",
        "Philip Glass - Einstein on the Beach",
    ])
}

actor IntelligenceManager {
    static let shared = IntelligenceManager()

    private init() {}

    /// Connects to the intelligence API using the given model.
    ///
    /// - Parameters:
    ///     - model: The model to use.
    /// - Returns: The connected intelligence API.
    /// - Throws: An error if the connection could not be established.
    private func connect(using model: IntelligenceModel) async throws -> OpenAI {
        let (isEnabled, token) = await MainActor.run {
            let isEnabled = UserDefaults.standard.bool(forKey: Setting.isIntelligenceEnabled)
            let token = UserDefaults.standard.string(forKey: model.setting) ?? ""
            return (isEnabled, token)
        }

        guard isEnabled else {
            throw IntelligenceManagerError.intelligenceDisabled
        }

        guard !token.isEmpty else {
            throw IntelligenceManagerError.missingToken
        }

        return await OpenAI(configuration: OpenAI.Configuration(
            token: token,
            host: model.host,
            basePath: model.path,
            parsingOptions: .fillRequiredFieldIfKeyNotFound,
        ))
    }

    /// Fills the specified target using the given prompt.
    ///
    /// - Parameters:
    ///     - target: The target to fill (playlist or queue).
    ///     - prompt: The prompt to use.
    /// - Throws: An error if the target could not be filled
    func fill(target: IntelligenceTarget, prompt: String) async throws {
        try await withTimeout(seconds: 30) {
            let model = await MainActor.run {
                UserDefaults.standard.string(forKey: Setting.intelligenceModel)
                    .flatMap { IntelligenceModel(rawValue: $0) } ?? .openAI
            }

            let client = try await self.connect(using: model)

            if case .playlist = target {
                try await ConnectionManager.command().loadPlaylist()
            }

            let albums = try await ConnectionManager.command().getAlbums()
            let albumDescriptions = albums.map(\.description).joined(separator: "\n")

            let result = try await client.chats(query: ChatQuery(
                messages: [
                    .init(role: .system, content: """
                    You are a music expert who knows every style, genre, artist, and album; from mainstream hits to obscure world music. You can sense any gathering's mood and craft the perfect playlist. Your job is to create a playlist that fits a short description we'll provide. The user will send you a list of available albums in the format `artist - title`.

                    The description for the playlist your should create is: \(prompt)
                    """)!,
                    .init(role: .user, content: albumDescriptions)!,
                ],
                model: model.model,
                responseFormat: .jsonSchema(
                    .init(
                        name: "intelligence_response",
                        description: nil,
                        schema: .derivedJsonSchema(IntelligenceResponse.self),
                        strict: true,
                    ),
                ),
            ))

            guard let content = result.choices.first?.message.content,
                  let data = content.data(using: .utf8)
            else {
                throw IntelligenceManagerError.noResponse
            }

            let response = try JSONDecoder().decode(IntelligenceResponse.self, from: data)

            let songs = try await self.collectSongs(from: response.playlist, albums: albums)

            try await self.addSongs(songs, to: target)
        }
    }

    /// Collects songs from the playlist response
    private func collectSongs(from playlist: [String], albums: [Album]) async throws -> [Song] {
        var songs: [Song] = []

        for albumName in playlist {
            guard let album = albums.first(where: { $0.description == albumName }) else {
                continue
            }

            try await songs.append(contentsOf: album.getSongs())
        }

        return songs
    }

    /// Adds songs to the specified target
    private func addSongs(_ songs: [Song], to target: IntelligenceTarget) async throws {
        switch target {
        case let .playlist(playlist):
            guard let playlist = playlist.wrappedValue else { return }
            try await ConnectionManager.command().add(songs: songs, to: .playlist(playlist))
            try await ConnectionManager.command().loadPlaylist(playlist)
        case .queue:
            try await ConnectionManager.command().add(songs: songs, to: .queue)
        }
    }

    /// Executes an async operation with a timeout.
    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw IntelligenceManagerError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
