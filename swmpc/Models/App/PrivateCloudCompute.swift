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
    @Guide(description: "Album names copied verbatim from the user's provided list, in 'Artist - Album' format, ordered for playback")
    var playlist: [String]
}

/// Generates playlists using Apple's server-side foundation model via Private
/// Cloud Compute.
///
/// Requires the `com.apple.developer.private-cloud-compute` entitlement and a
/// device that supports Apple Intelligence. No API token is needed.
nonisolated enum PrivateCloudCompute {
    /// Wrapper for the model handle, since `PrivateCloudComputeLanguageModel`
    /// only exists on OS 27 while this namespace stays available on OS 26.
    @available(iOS 27.0, macOS 27.0, *)
    private nonisolated enum Model {
        static let shared = PrivateCloudComputeLanguageModel()
    }

    /// Whether the device and system are ready to serve PCC requests. Always
    /// `false` below iOS/macOS 27.
    static var isAvailable: Bool {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            return false
        }

        return Model.shared.isAvailable
    }

    /// Generates a playlist by prompting the Private Cloud Compute model.
    ///
    /// - Parameters:
    ///   - instructions: System instructions for the model.
    ///   - prompt: The user prompt containing the playlist description and
    ///             available albums.
    /// - Returns: Array of album names in "Artist - Album" format.
    /// - Throws: `IntelligenceManagerError.appleIntelligenceUnavailable` below
    ///           iOS/macOS 27, `PrivateCloudComputeLanguageModel.Error` or
    ///           generation errors.
    static func generatePlaylist(instructions: String, prompt: String) async throws -> [String] {
        guard #available(iOS 27.0, macOS 27.0, *) else {
            throw IntelligenceManagerError.appleIntelligenceUnavailable
        }

        let session = LanguageModelSession(
            model: Model.shared,
            instructions: Instructions(instructions),
        )

        let response = try await session.respond(
            to: Prompt(prompt),
            generating: PrivateCloudComputeResponse.self,
        )

        return response.content.playlist
    }
}
