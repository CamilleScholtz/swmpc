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
            intent: ToggleConsumeIntent(),
            phrases: [
                "Toggle consume in \(.applicationName)",
                "Consume music in \(.applicationName)",
                "Turn on consume in \(.applicationName)",
                "Turn off consume in \(.applicationName)",
                "Enable consume in \(.applicationName)",
                "Disable consume in \(.applicationName)",
                "Consume mode in \(.applicationName)",
            ],
            shortTitle: "Toggle Consume",
            systemImageName: "flame",
        )

        AppShortcut(
            intent: ToggleShuffleIntent(),
            phrases: [
                "Toggle shuffle in \(.applicationName)",
                "Shuffle music in \(.applicationName)",
                "Turn on shuffle in \(.applicationName)",
                "Turn off shuffle in \(.applicationName)",
                "Enable shuffle in \(.applicationName)",
                "Disable shuffle in \(.applicationName)",
                "Toggle random in \(.applicationName)",
                "Shuffle random in \(.applicationName)",
                "Turn on random in \(.applicationName)",
                "Turn off random in \(.applicationName)",
                "Enable random in \(.applicationName)",
                "Disable random in \(.applicationName)",
            ],
            shortTitle: "Toggle Shuffle",
            systemImageName: "shuffle",
        )

        AppShortcut(
            intent: ToggleRepeatIntent(),
            phrases: [
                "Toggle repeat in \(.applicationName)",
                "Repeat music in \(.applicationName)",
                "Turn on repeat in \(.applicationName)",
                "Turn off repeat in \(.applicationName)",
                "Enable repeat in \(.applicationName)",
                "Disable repeat in \(.applicationName)",
                "Loop music in \(.applicationName)",
            ],
            shortTitle: "Toggle Repeat",
            systemImageName: "repeat",
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
