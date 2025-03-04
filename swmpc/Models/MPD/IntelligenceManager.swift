//
//  IntelligenceManager.swift
//  swmpc
//
//  Created by Camille Scholtz on 04/03/2025.
//

@preconcurrency import OpenAI
import SwiftUI

enum IntelligenceManagerError: Error {
    case missingToken
    case noResponse
    case invalideResponse
}

actor IntelligenceManager {
    static let shared = IntelligenceManager()

    private init() {}

    @MainActor
    func createSmartPlaylist(using playlist: Playlist, prompt: String) async throws {
        @AppStorage(Setting.openAIToken) var openAIToken = ""
        guard !openAIToken.isEmpty else {
            throw IntelligenceManagerError.missingToken
        }

        let openAI = OpenAI(apiToken: openAIToken)

        try await ConnectionManager.command().loadPlaylist()
        let albums = try await ConnectionManager.command().getAlbums()

        struct output: StructuredOutput {
            let playlist: [String]

            static let example: Self = .init(playlist: [
                .init("Philip Glass - Koyaanisqatsi"),
                .init("Philip Glass - Glassworks"),
                .init("Philip Glass - Einstein on the Beach"),
            ])
        }

        let result = try await openAI.chats(query: ChatQuery(
            messages: [
                .init(role: .system, content: "Create a playlist that fits a description we will supply later. The user will send you all available albums in the format 'artist - title'. Return the albums (in format 'artist - title', using the EXACT same naming as was supplied to you) that should be in the playlist the following description: \(prompt)")!,
                .init(role: .user, content: albums.map(\.description).joined(separator: "\n"))!,
            ],
            model: .gpt4_o_mini,
            responseFormat: .jsonSchema(name: "output", type: output.self)
        ))

        guard let response = result.choices.first?.message.content?.string else {
            throw IntelligenceManagerError.noResponse
        }

        let data = try JSONDecoder().decode(output.self, from: Data(response.utf8))
        var songs: [Song] = []

        for row in data.playlist {
            guard let album = albums.first(where: { $0.description == row }) else {
                continue
            }

            try await songs.append(contentsOf: ConnectionManager.command().getSongs(for: album))
        }

        print(songs)

        try await ConnectionManager.command().addToPlaylist(playlist, songs: songs, force: true)
    }
}
