//
//  IntelligenceManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/03/2025.
//

import KeychainStorageKit
import OpenAI
import SwiftUI

enum IntelligenceManagerError: Error {
    case intelligenceDisabled
    case missingToken
    case noResponse
    case timeout
}

enum IntelligenceModel: String, Identifiable, CaseIterable {
    var id: String { rawValue }

    case openAI
    case deepSeek
    case gemini
    case grok
    case claude

    var name: String {
        switch self {
        case .openAI:
            "OpenAI"
        case .deepSeek:
            "DeepSeek"
        case .gemini:
            "Gemini"
        case .grok:
            "Grok"
        case .claude:
            "Claude"
        }
    }

    var model: String {
        switch self {
        case .openAI:
            "gpt-4.1-mini"
        case .deepSeek:
            "deepseek-chat"
        case .gemini:
            "gemini-2.0-flash"
        case .grok:
            "grok-3-mini-beta"
        case .claude:
            "claude-3-5-haiku-latest"
        }
    }

    var host: String {
        switch self {
        case .openAI:
            "api.openai.com"
        case .deepSeek:
            "api.deepseek.com"
        case .gemini:
            "generativelanguage.googleapis.com"
        case .grok:
            "api.x.ai"
        case .claude:
            "api.anthropic.com"
        }
    }

    var path: String {
        switch self {
        case .gemini:
            "/v1beta/openai"
        case .claude:
            "/v1/messages"
        default:
            "/v1"
        }
    }

    var setting: String {
        switch self {
        case .openAI:
            Setting.openAIToken
        case .deepSeek:
            Setting.deepSeekToken
        case .gemini:
            Setting.geminiToken
        case .grok:
            Setting.grokToken
        case .claude:
            Setting.claudeToken
        }
    }

    // NOTE: DeepSeek is currently disabled because it does not support
    // structured output.
    var isEnabled: Bool {
        switch self {
        case .deepSeek:
            false
        default:
            true
        }
    }
}

struct IntelligenceResponse: JSONSchemaConvertible {
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
    @MainActor
    private func connect(using model: IntelligenceModel) async throws ->
        OpenAI
    {
        @AppStorage(Setting.isIntelligenceEnabled) var isIntelligenceEnabled =
            false
        guard isIntelligenceEnabled else {
            throw IntelligenceManagerError.intelligenceDisabled
        }

        @KeychainStorage(model.setting) var token: String?
        guard let token, !token.isEmpty else {
            throw IntelligenceManagerError.missingToken
        }

        return OpenAI(configuration: .init(
            token: token,
            host: model.host,
            basePath: model.path,
            parsingOptions: .fillRequiredFieldIfKeyNotFound
        ))
    }

    /// Creates a playlist using the given prompt.
    ///
    /// - Parameters:
    ///     - playlist: The playlist to fill.
    ///     - prompt: The prompt to use.
    /// - Throws: An error if the playlist could not be filled
    @MainActor
    func fillPlaylist(using playlist: Playlist, prompt: String) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            @AppStorage(Setting.intelligenceModel) var model = IntelligenceModel
                .openAI

            let client = try await connect(using: model)

            group.addTask {
                try await ConnectionManager.command().loadPlaylist()
                let albums = try await ConnectionManager.command().getAlbums()

                let result = try await client.chats(query: ChatQuery(
                    messages: [
                        .init(role: .system, content: """
                        You are a music expert who knows every style, genre, artist, and album; from mainstream hits to obscure world music. You can sense any gathering's mood and craft the perfect playlist. Your job is to create a playlist that fits a short description we'll provide. The user will send you a list of available albums in the format `artist - title`.

                        The description for the playlist your should create is: \(prompt)
                        """)!,
                        .init(role: .user, content: albums.map(\.description).joined(
                            separator: "\n"))!,
                    ],
                    model: model.model,
                    responseFormat: .derivedJsonSchema(name: "intelligence_response", type: IntelligenceResponse.self)
                ))

                guard let response = result.choices.first?.message.content else {
                    throw IntelligenceManagerError.noResponse
                }

                struct Playlist: Decodable {
                    let playlist: [String]
                }
                let data = try JSONDecoder().decode(Playlist.self, from: Data(
                    response.utf8))

                var songs: [Song] = []

                for row in data.playlist {
                    guard let album = albums.first(where: {
                        $0.description == row
                    }) else {
                        continue
                    }

                    try await songs.append(contentsOf: ConnectionManager.command()
                        .getSongs(for: album))
                }

                try await ConnectionManager.command().addToPlaylist(playlist, songs:
                    songs)
                try await ConnectionManager.command().loadPlaylist(playlist)
            }

            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw IntelligenceManagerError.timeout
            }

            try await group.next()

            group.cancelAll()
        }
    }
}
