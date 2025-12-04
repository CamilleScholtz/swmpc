//
//  Delegate.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import AppIntents
import ButtonKit
import SwiftUI
#if os(macOS)
    import SFSafeSymbols
#endif

@main
struct Delegate: App {
    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        @Environment(\.openWindow) private var openWindow
    #endif

    #if os(iOS)
        static let serverManager = ServerManager()
        static let mpd = MPD()
    #endif

    let navigator = NavigationManager()

    #if os(macOS)
        init() {
            AppShortcuts.updateAppShortcutParameters()
        }
    #endif

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(navigator)
            #if os(iOS)
                .environment(Delegate.serverManager)
                .environment(Delegate.mpd)
            #elseif os(macOS)
                .environment(appDelegate.serverManager)
                .environment(appDelegate.mpd)
            #endif
        }
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About swmpc") {
                    openWindow(id: "about")
                }
            }
            CommandMenu("Controls") {
                AsyncButton(appDelegate.mpd.status.isPlaying ? "Pause" : "Play", systemSymbol: appDelegate.mpd.status.isPlaying == true ? .pauseFill : .playFill) {
                    try await ConnectionManager.command {
                        try await $0.pause(appDelegate.mpd.status.isPlaying)
                    }
                }
                .keyboardShortcut(.space)

                AsyncButton("Next Song", systemSymbol: .forwardFill) {
                    try await ConnectionManager.command {
                        try await $0.next()
                    }
                }
                .keyboardShortcut(.downArrow, modifiers: [.command])

                AsyncButton("Previous Song", systemSymbol: .backwardFill) {
                    try await ConnectionManager.command {
                        try await $0.previous()
                    }
                }
                .keyboardShortcut(.upArrow, modifiers: [.command])

                Divider()

                AsyncButton("Add Current Song to Favorites", systemSymbol: .heartFill) {
                    guard let song = appDelegate.mpd.status.song else {
                        return
                    }

                    let isFavorited = appDelegate.mpd.playlists.favorites.contains { $0.file == song.file }

                    if isFavorited {
                        try await ConnectionManager.command {
                            try await $0.remove(songs: [song], from: .favorites)
                        }
                    } else {
                        try await ConnectionManager.command {
                            try await $0.add(songs: [song], to: .favorites)
                        }
                    }
                }
                .keyboardShortcut("l", modifiers: [.command, .option])

                Button("Search Library", systemSymbol: .magnifyingglass) {
                    NotificationCenter.default.post(name: .startSearchingNotication, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Divider()

                AsyncButton("Toggle Repeat", systemSymbol: .repeat) {
                    try await ConnectionManager.command {
                        try await $0.repeat(!(appDelegate.mpd.status.isRepeat ?? false))
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])

                AsyncButton("Toggle Shuffle", systemSymbol: .shuffle) {
                    try await ConnectionManager.command {
                        try await $0.random(!(appDelegate.mpd.status.isRandom ?? false))
                    }
                }
                .keyboardShortcut("s", modifiers: [.command])

                Divider()

                AsyncButton("Toggle Consume", systemSymbol: .flame) {
                    try await ConnectionManager.command {
                        try await $0.consume(!(appDelegate.mpd.status.isConsume ?? false))
                    }
                }

                Button("Clear Queue", systemSymbol: .trash) {
                    navigator.showClearQueueAlert = true
                }
                .keyboardShortcut(.delete, modifiers: [.command, .option])

                Divider()

                AsyncButton("Reload Library", systemSymbol: .arrowClockwise) {
                    try await ConnectionManager.command {
                        try await $0.update()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
            }

            if let playlists = appDelegate.mpd.playlists.playlists {
                CommandMenu("Playlists") {
                    Menu("Load Playlist", systemImage: SFSymbol.musicNoteList.rawValue) {
                        ForEach(playlists) { playlist in
                            AsyncButton(playlist.name) {
                                try await ConnectionManager.command {
                                    try await $0.loadPlaylist(playlist)
                                }
                            }
                        }
                    }
                }
            }
        }
        #endif

        #if os(macOS)
            Settings {
                SettingsView()
                    .environment(appDelegate.serverManager)
                    .environment(appDelegate.mpd)
            }

            Window("About swmpc", id: "about") {
                AboutView()
                    .environment(appDelegate.mpd)
                    .toolbar(removing: .title)
                    .toolbarBackground(.hidden, for: .windowToolbar)
                    .windowMinimizeBehavior(.disabled)
            }
            .windowBackgroundDragBehavior(.enabled)
            .windowResizability(.contentSize)
            .restorationBehavior(.disabled)
        #endif
    }
}

#if os(macOS)
    final class AppDelegate: NSObject, NSApplicationDelegate {
        private(set) static var shared: AppDelegate?

        let serverManager = ServerManager()
        let mpd = MPD()

        private lazy var popoverAnchor = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let popover = NSPopover()

        private var changeImageTask: Task<Void, Never>?

        @AppStorage(Setting.showStatusBar) var showStatusBar = true
        @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true

        enum MenuAction: Int {
            case play = 100
            case pause = 101
            case nextSong = 102
            case previousSong = 103
            case addToFavorites = 104
        }

        func applicationDidFinishLaunching(_: Notification) {
            AppDelegate.shared = self

            if showStatusBar {
                configureStatusItem()
                configurePopover()
            }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleStatusBarSettingChanged),
                name: .statusBarSettingChangedNotification,
                object: nil,
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTerminate),
                name: NSApplication.willTerminateNotification,
                object: nil,
            )
        }

        func applicationDockMenu(_: NSApplication) -> NSMenu? {
            let menu = NSMenu()

            let playPauseItem = NSMenuItem(
                title: mpd.status.isPlaying ? "Pause" : "Play",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: "",
            )
            playPauseItem.tag = mpd.status.isPlaying ? MenuAction.pause.rawValue : MenuAction.play.rawValue
            playPauseItem.image = NSImage(systemSymbol: mpd.status.isPlaying ? .pauseFill : .playFill)
            menu.addItem(playPauseItem)

            let nextItem = NSMenuItem(
                title: "Next song",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: "",
            )
            nextItem.tag = MenuAction.nextSong.rawValue
            nextItem.image = NSImage(systemSymbol: .forwardFill)
            menu.addItem(nextItem)

            let previousItem = NSMenuItem(
                title: "Previous song",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: "",
            )
            previousItem.tag = MenuAction.previousSong.rawValue
            previousItem.image = NSImage(systemSymbol: .backwardFill)
            menu.addItem(previousItem)

            menu.addItem(NSMenuItem.separator())

            let favoritesItem = NSMenuItem(
                title: "Add current song to favorites",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: "",
            )
            favoritesItem.tag = MenuAction.addToFavorites.rawValue
            favoritesItem.image = NSImage(systemSymbol: .heartFill)
            menu.addItem(favoritesItem)

            return menu
        }

        private func configureStatusItem() {
            guard let anchorButton = popoverAnchor.button else {
                return
            }

            anchorButton.sendAction(on: [.leftMouseDown, .rightMouseDown])
            anchorButton.action = #selector(handleButtonAction)

            if showStatusBar {
                guard let statusButton = statusItem.button else {
                    return
                }

                statusButton.sendAction(on: [.leftMouseDown, .rightMouseDown])
                statusButton.action = #selector(handleButtonAction)
            }

            setPopoverAnchorImage()
        }

        private func configurePopover() {
            popover.behavior = .transient

            let viewController = NSViewController()
            viewController.view = NSHostingView(
                rootView: PopoverView()
                    .environment(mpd),
            )
            popover.contentViewController = viewController
        }

        func setPopoverAnchorImage(changed: String? = nil) {
            guard showStatusBar, !popover.isShown, let button = popoverAnchor.button else {
                return
            }

            switch changed {
            case "play":
                button.image = NSImage(systemSymbol: .playFill, accessibilityDescription: "play")
            case "pause":
                button.image = NSImage(systemSymbol: .pauseFill, accessibilityDescription: "pause")
            case "stop":
                button.image = NSImage(systemSymbol: .stopFill, accessibilityDescription: "stop")
            case "consume":
                button.image = NSImage(systemSymbol: .flame, accessibilityDescription: "consume")
            case "preserve":
                button.image = NSImage(systemSymbol: .flame, accessibilityDescription: "preserve")
            case "random":
                button.image = NSImage(systemSymbol: .shuffle, accessibilityDescription: "random")
            case "sequential":
                button.image = NSImage(systemSymbol: .arrowUpArrowDown, accessibilityDescription: "sequential")
            case "repeat":
                button.image = NSImage(systemSymbol: .repeat, accessibilityDescription: "repeat")
            case "single":
                button.image = NSImage(systemSymbol: .return, accessibilityDescription: "single")
            default:
                button.image = NSImage(systemSymbol: .musicNote, accessibilityDescription: "swmpc")
                return
            }

            changeImageTask?.cancel()
            changeImageTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled, let self, let button = popoverAnchor.button else {
                    return
                }

                button.image = NSImage(systemSymbol: .musicNote, accessibilityDescription: "swmpc")
            }
        }

        func setStatusItemTitle() {
            guard showStatusBar, let button = statusItem.button else {
                return
            }

            guard showStatusbarSong else {
                button.title = ""
                return
            }

            guard var description = mpd.status.song?.description else {
                button.title = ""
                return
            }

            if description.count > 80 {
                description = String(description.prefix(80)) + "…"
            }

            button.title = description
        }

        private func togglePopover(_ sender: NSStatusBarButton?) {
            guard let sender else {
                return
            }

            if popover.isShown {
                popover.performClose(sender)
            } else {
                showPopover()

                // https://stackoverflow.com/a/73322639/14351818
                popover.contentViewController?.view.window?.makeKey()
            }
        }

        private func showPopover() {
            guard let button = popoverAnchor.button else {
                return
            }

            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .maxY,
            )
        }

        @objc private func handleTerminate(_: Notification) {
            popover.performClose(nil)
            NSApplication.shared.terminate(self)
        }

        @objc private func handleButtonAction(_ sender: NSStatusBarButton?) {
            guard let event = NSApp.currentEvent else {
                return
            }

            switch event.type {
            case .rightMouseDown:
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command {
                        try await $0.pause(mpd.status.isPlaying)
                    }
                }
            default:
                togglePopover(sender)
            }
        }

        @objc private func handleMenuItemAction(_ sender: NSMenuItem) {
            guard let action = MenuAction(rawValue: sender.tag) else {
                return
            }

            switch action {
            case .play:
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command {
                        try await $0.pause(false)
                    }
                }
            case .pause:
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command {
                        try await $0.pause(true)
                    }
                }
            case .nextSong:
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command {
                        try await $0.next()
                    }
                }
            case .previousSong:
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command {
                        try await $0.previous()
                    }
                }
            case .addToFavorites:
                Task(priority: .userInitiated) {
                    guard let song = mpd.status.song else {
                        return
                    }

                    let isFavorited = mpd.playlists.favorites.contains { $0.file == song.file }

                    if isFavorited {
                        try? await ConnectionManager.command {
                            try await $0.remove(songs: [song], from: .favorites)
                        }
                    } else {
                        try? await ConnectionManager.command {
                            try await $0.add(songs: [song], to: .favorites)
                        }
                    }
                }
            }
        }

        @objc private func handleStatusBarSettingChanged(_: Notification) {
            if showStatusBar {
                configureStatusItem()
                configurePopover()
                setStatusItemTitle()
            } else {
                NSStatusBar.system.removeStatusItem(popoverAnchor)
                NSStatusBar.system.removeStatusItem(statusItem)

                popoverAnchor = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            }
        }
    }
#endif
