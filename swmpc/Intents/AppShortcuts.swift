//
//  AppShortcuts.swift
//  swmpc
//
//  Created by Camille Scholtz on 26/05/2025.
//

import AppIntents
import SwiftUI

struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlayPauseIntent(),
            phrases: [
                "Play or pause \(.applicationName)",
                "Toggle playback in \(.applicationName)",
                "Play music with \(.applicationName)",
                "Pause music with \(.applicationName)",
                "Play \(.applicationName)",
                "Pause \(.applicationName)",
                "Resume playback in \(.applicationName)",
                "Start music in \(.applicationName)",
                "Stop music in \(.applicationName)",
            ],
            shortTitle: "Play/Pause",
            systemImageName: "playpause",
        )

        AppShortcut(
            intent: NextSongIntent(),
            phrases: [
                "Skip song in \(.applicationName)",
                "Next song in \(.applicationName)",
                "Play next in \(.applicationName)",
                "Skip track in \(.applicationName)",
                "Next track in \(.applicationName)",
            ],
            shortTitle: "Next Song",
            systemImageName: "forward.fill",
        )

        AppShortcut(
            intent: PreviousSongIntent(),
            phrases: [
                "Previous song in \(.applicationName)",
                "Go back in \(.applicationName)",
                "Play previous in \(.applicationName)",
                "Previous track in \(.applicationName)",
                "Last song in \(.applicationName)",
            ],
            shortTitle: "Previous Song",
            systemImageName: "backward.fill",
        )

        AppShortcut(
            intent: ClearQueueIntent(),
            phrases: [
                "Clear queue in \(.applicationName)",
                "Clear the queue in \(.applicationName)",
                "Empty queue in \(.applicationName)",
                "Remove all songs in \(.applicationName)",
            ],
            shortTitle: "Clear Queue",
            systemImageName: "xmark.circle",
        )

        AppShortcut(
            intent: SetPlaybackModeIntent(),
            phrases: [
                "Toggle \(\.$mode) in \(.applicationName)",
                "Enable \(\.$mode) in \(.applicationName)",
                "Disable \(\.$mode) in \(.applicationName)",
                "Turn on \(\.$mode) in \(.applicationName)",
                "Turn off \(\.$mode) in \(.applicationName)",
                "Set \(\.$mode) in \(.applicationName)",
            ],
            shortTitle: "Playback Mode",
            systemImageName: "slider.horizontal.3",
        )

        AppShortcut(
            intent: CurrentSongIntent(),
            phrases: [
                "What's playing in \(.applicationName)",
                "Current song in \(.applicationName)",
                "Now playing in \(.applicationName)",
                "What song is this in \(.applicationName)",
                "What's this song in \(.applicationName)",
                "Song info in \(.applicationName)",
                "Tell me what's playing in \(.applicationName)",
            ],
            shortTitle: "What's Playing",
            systemImageName: "music.note",
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .yellow
}
