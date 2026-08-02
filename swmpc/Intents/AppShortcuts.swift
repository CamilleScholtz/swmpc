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

        AppShortcut(
            intent: PlayPlaylistIntent(),
            phrases: [
                "Play playlist \(\.$playlist) in \(.applicationName)",
                "Play \(\.$playlist) in \(.applicationName)",
                "Put on \(\.$playlist) in \(.applicationName)",
                "Listen to \(\.$playlist) in \(.applicationName)",
            ],
            shortTitle: "Play Playlist",
            systemImageName: "music.note.list",
        )

        AppShortcut(
            intent: SearchAndPlayIntent(),
            phrases: [
                "Search and play in \(.applicationName)",
                "Play something in \(.applicationName)",
                "Search for music in \(.applicationName)",
                "Find and play music in \(.applicationName)",
            ],
            shortTitle: "Search and Play",
            systemImageName: "magnifyingglass",
        )

        AppShortcut(
            intent: FavoriteSongIntent(),
            phrases: [
                "Favorite this song in \(.applicationName)",
                "Add this song to favorites in \(.applicationName)",
                "Like this song in \(.applicationName)",
                "Unfavorite this song in \(.applicationName)",
                "Remove this song from favorites in \(.applicationName)",
            ],
            shortTitle: "Favorite Song",
            systemImageName: "heart",
        )

        AppShortcut(
            intent: GeneratePlaylistIntent(),
            phrases: [
                "Generate a playlist in \(.applicationName)",
                "Make me a playlist in \(.applicationName)",
                "Create a playlist in \(.applicationName)",
                "Generate a queue in \(.applicationName)",
            ],
            shortTitle: "Generate Playlist",
            systemImageName: "sparkles",
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .yellow
}
