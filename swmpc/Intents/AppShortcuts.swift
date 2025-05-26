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
                "Resume playback in \(.applicationName)"
            ],
            shortTitle: "Play/Pause",
            systemImageName: "playpause"
        )

        AppShortcut(
            intent: NextSongIntent(),
            phrases: [
                "Skip song in \(.applicationName)",
                "Next song in \(.applicationName)",
                "Play next in \(.applicationName)",
            ],
            shortTitle: "Next Song",
            systemImageName: "forward.fill"
        )

        AppShortcut(
            intent: PreviousSongIntent(),
            phrases: [
                "Previous song in \(.applicationName)",
                "Go back in \(.applicationName)",
                "Play previous in \(.applicationName)",
            ],
            shortTitle: "Previous Song",
            systemImageName: "backward.fill"
        )

        AppShortcut(
            intent: ToggleShuffleIntent(),
            phrases: [
                "Toggle shuffle in \(.applicationName)",
                "Shuffle music in \(.applicationName)",
                "Turn on shuffle in \(.applicationName)",
                "Turn off shuffle in \(.applicationName)",
            ],
            shortTitle: "Toggle Shuffle",
            systemImageName: "shuffle"
        )

        AppShortcut(
            intent: ToggleRepeatIntent(),
            phrases: [
                "Toggle repeat in \(.applicationName)",
                "Repeat music in \(.applicationName)",
                "Turn on repeat in \(.applicationName)",
                "Turn off repeat in \(.applicationName)",
            ],
            shortTitle: "Toggle Repeat",
            systemImageName: "repeat"
        )

        AppShortcut(
            intent: CurrentSongIntent(),
            phrases: [
                "What's playing in \(.applicationName)",
                "Current song in \(.applicationName)",
                "Now playing in \(.applicationName)",
                "What song is this in \(.applicationName)",
            ],
            shortTitle: "What's Playing",
            systemImageName: "music.note"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .yellow
}
