//
//  AppIntent+MPD.swift
//  swmpc
//
//  Created by Camille Scholtz on 27/05/2025.
//

import AppIntents
import MPDKit

extension AppIntent {
    /// Provides access to the shared MPD instance appropriate for the current
    /// platform.
    ///
    /// On iOS, accesses the MPD instance from the global Delegate.
    /// On macOS, accesses the MPD instance from the shared AppDelegate.
    @MainActor
    var mpd: MPD {
        #if os(iOS)
            Delegate.mpd
        #elseif os(macOS)
            AppDelegate.shared!.mpd
        #endif
    }

    /// Runs an MPD command, converting failures into an error whose message
    /// Siri can speak, instead of surfacing a technical connection error.
    func command<T: Sendable>(
        _ operation: @Sendable (ConnectionManager<CommandMode>) async throws
            -> T,
    ) async throws -> T {
        do {
            return try await ConnectionManager.command(operation)
        } catch {
            throw AppIntentError(description: "Could not reach the MPD server")
        }
    }
}
