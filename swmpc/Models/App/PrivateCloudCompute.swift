//
//  PrivateCloudCompute.swift
//  swmpc
//
//  Created by Camille Scholtz on 12/07/2026.
//

import FoundationModels

/// Response structure for playlists generated through Private Cloud Compute.
///
/// Mirrors `IntelligenceResponse`, but uses the FoundationModels `@Generable`
/// macro. It lives in this file — which does not import AnyLanguageModel — so
/// the macro does not clash with the AnyLanguageModel macro of the same name.
@Generable
private nonisolated struct PrivateCloudComputeResponse {
    /// Array of album names in "Artist - Album" format.
    @Guide(description: "Album names in 'Artist - Album' format, selected from the user's provided list")
    var playlist: [String]
}

/// Generates playlists using Apple's server-side foundation model via Private
/// Cloud Compute.
///
/// Requires the `com.apple.developer.private-cloud-compute` entitlement and a
/// device that supports Apple Intelligence. No API token is needed.
nonisolated enum PrivateCloudCompute {
    private static let model = PrivateCloudComputeLanguageModel()

    /// Whether the device and system are ready to serve PCC requests.
    static var isAvailable: Bool {
        model.isAvailable
    }

    /// Generates a playlist by prompting the Private Cloud Compute model.
    ///
    /// - Parameters:
    ///   - instructions: System instructions for the model.
    ///   - prompt: The user prompt containing the playlist description and
    ///             available albums.
    /// - Returns: Array of album names in "Artist - Album" format.
    /// - Throws: `PrivateCloudComputeLanguageModel.Error` or generation
    ///           errors.
    static func generatePlaylist(instructions: String, prompt: String) async throws -> [String] {
        let session = LanguageModelSession(
            model: model,
            instructions: Instructions(instructions),
        )

        let response = try await session.respond(
            to: Prompt(prompt),
            generating: PrivateCloudComputeResponse.self,
        )

        return response.content.playlist
    }
}
