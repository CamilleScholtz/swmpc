//
//  PreviousSongIntent.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct PreviousSongIntent: AppIntent {
    static let title: LocalizedStringResource = "Previous Song"
    static let description = IntentDescription("Go back to the previous song")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await ConnectionManager.command().previous()

        let song = await MainActor.run {
            #if os(iOS)
                Delegate.mpd.status.song
            #elseif os(macOS)
                AppDelegate.shared?.mpd.status.song
            #endif
        }

        var dialog = "Playing "
        if song != nil {
            dialog += "\(song!.title) by \(song!.artist)"
        } else {
            dialog += "previous song"
        }

        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }

    static let openAppWhenRun: Bool = false
}
