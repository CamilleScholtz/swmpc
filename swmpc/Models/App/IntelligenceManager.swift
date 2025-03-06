//
//  IntelligenceManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/03/2025.
//

@preconcurrency import OpenAI
import SwiftUI

enum IntelligenceManagerError: Error {
    case intelligenceDisabled
    case missingToken
    case noResponse
    case invalideResponse
}

enum IntelligenceModel: String {
    case deepSeek = "deepseek-chat"
    case openAI = "gpt-4o"
}

actor IntelligenceManager {
    static let shared = IntelligenceManager()

    private init() {}

    @MainActor
    func connect(using model: IntelligenceModel) async throws -> OpenAI {
        @AppStorage(Setting.isIntelligenceEnabled) var isIntelligenceEnabled = false
        guard isIntelligenceEnabled else {
            throw IntelligenceManagerError.intelligenceDisabled
        }

        var token: String
        var host: String

        switch model {
        case .deepSeek:
            @AppStorage(Setting.deepSeekToken) var deepSeekToken = ""
            guard !deepSeekToken.isEmpty else {
                throw IntelligenceManagerError.missingToken
            }

            token = deepSeekToken
            host = "api.deepseek.com"
        case .openAI:
            @AppStorage(Setting.openAIToken) var openAIToken = ""
            guard !openAIToken.isEmpty else {
                throw IntelligenceManagerError.missingToken
            }

            token = openAIToken
            host = "api.openai.com"
        }

        return OpenAI(configuration: .init(token: token, host: host))
    }

    @MainActor
    func createPlaylist(using playlist: Playlist, prompt: String) async throws {
        @AppStorage(Setting.intelligenceModel) var model = IntelligenceModel.deepSeek

        let client = try await connect(using: model)

        try await ConnectionManager.command().loadPlaylist()
        let albums = try await ConnectionManager.command().getAlbums()

        let result = try await client.chats(query: ChatQuery(
            messages: [
                .init(role: .system, content: """
                You are a music expert who knows every style, genre, artist, and album; from mainstream hits to obscure world music. You can sense any gathering’s mood and craft the perfect playlist. Your job is to create a playlist that perfectly fits a shoort description we’ll provide. The user will send you albums in the format `artist - title`. Return, in JSON format, those albums, in that exact same `artist - title` format, which match the given description.

                EXAMPLE JSON OUTPUT:
                {
                    "playlist": [
                        "Philip Glass - Koyaanisqatsi",
                        "Philip Glass - Glassworks",
                        "Philip Glass - Einstein on the Beach"
                    ]
                }

                THE DESCRIPTION: \(prompt)
                """)!,
                .init(role: .user, content: albums.map(\.description).joined(separator: "\n"))!,
            ],
            model: model.rawValue,
            responseFormat: .jsonObject
        ))

        guard let response = result.choices.first?.message.content?.string else {
            throw IntelligenceManagerError.noResponse
        }

        struct Playlist: Decodable {
            let playlist: [String]
        }
        let data = try JSONDecoder().decode(Playlist.self, from: Data(response.utf8))

        var songs: [Song] = []

        for row in data.playlist {
            guard let album = albums.first(where: { $0.description == row }) else {
                continue
            }

            try await songs.append(contentsOf: ConnectionManager.command().getSongs(for: album))
        }

        try await ConnectionManager.command().addToPlaylist(playlist, songs: songs)
        try await ConnectionManager.command().loadPlaylist(playlist)
    }
}
