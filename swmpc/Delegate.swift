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

#if os(iOS)
    typealias PlatformImage = UIImage
#elseif os(macOS)
    typealias PlatformImage = NSImage
#endif

@main
struct Delegate: App {
    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    #if os(iOS)
        static let mpd = MPD()
    #endif
    let navigator = NavigationManager()

    init() {
        AppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(navigator)
                .environment(LoadingManager.shared)
            #if os(iOS)
                .environment(Delegate.mpd)
            #elseif os(macOS)
                .environment(appDelegate.mpd)
                .onAppear {
                    for window in NSApplication.shared.windows {
                        window.tabbingMode = .disallowed
                    }
                }
            #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Controls") {
                AsyncButton(appDelegate.mpd.status.isPlaying == true ? "Pause" : "Play") {
                    try await ConnectionManager.command().pause(appDelegate.mpd.status.isPlaying)
                }
                .keyboardShortcut(.space)

                AsyncButton("Next Song") {
                    try await ConnectionManager.command().next()
                }
                .keyboardShortcut(.downArrow, modifiers: [.command])

                AsyncButton("Previous Song") {
                    try await ConnectionManager.command().previous()
                }
                .keyboardShortcut(.upArrow, modifiers: [.command])

                Divider()

                AsyncButton("Add Current Song to Favorites") {
                    guard let song = appDelegate.mpd.status.song else {
                        return
                    }

                    let isFavorited = appDelegate.mpd.playlists.favorites.contains { $0.url == song.url }

                    if isFavorited {
                        try await ConnectionManager.command().remove(songs: [song], from: .favorites)
                    } else {
                        try await ConnectionManager.command().add(songs: [song], to: .favorites)
                    }
                }
                .keyboardShortcut("l", modifiers: [.command, .option])

                Button("Go to Current Song") {
                    NotificationCenter.default.post(name: .scrollToCurrentNotification, object: true)
                }
                .keyboardShortcut("l", modifiers: [.command])

                Button("Search Library") {
                    NotificationCenter.default.post(name: .startSearchingNotication, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Divider()

                AsyncButton("Toggle Repeat") {
                    try await ConnectionManager.command().repeat(!(appDelegate.mpd.status.isRepeat ?? false))
                }
                .keyboardShortcut("r", modifiers: [.command])

                AsyncButton("Toggle Shuffle") {
                    try await ConnectionManager.command().random(!(appDelegate.mpd.status.isRandom ?? false))
                }
                .keyboardShortcut("s", modifiers: [.command])

                Divider()

                AsyncButton("Clear Queue") {
                    try await ConnectionManager.command().clearQueue()
                }
                .keyboardShortcut(.delete, modifiers: [.command, .option])

                Divider()

                AsyncButton("Reload Library") {
                    try await ConnectionManager.command().update()
                    try await appDelegate.mpd.database.set(force: true)
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
            }

            if let playlists = appDelegate.mpd.playlists.playlists {
                CommandMenu("Playlists") {
                    Menu("Load Playlist") {
                        ForEach(playlists) { playlist in
                            AsyncButton(playlist.name) {
                                try await ConnectionManager.command().loadPlaylist(playlist)
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
            }
        #endif
    }
}

#if os(macOS)
    @MainActor
    final class AppDelegate: NSObject, NSApplicationDelegate {
        private(set) static var shared: AppDelegate!

        let mpd = MPD()

        private lazy var popoverAnchor = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let popover = NSPopover()

        private var changeImageTask: Task<Void, Never>?

        @AppStorage(Setting.showStatusBar) var showStatusBar = true
        @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true
        @AppStorage(Setting.runAsAgent) var runAsAgent = false

        enum MenuAction: Int {
            case play = 100
            case pause = 101
            case nextSong = 102
            case previousSong = 103
            case addToFavorites = 104
        }

        func applicationDidFinishLaunching(_: Notification) {
            AppDelegate.shared = self

            NSApp.setActivationPolicy(runAsAgent ? .prohibited : .regular)

            if showStatusBar {
                configureStatusItem()
                configurePopover()
            }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleStatusBarSettingChanged),
                name: .statusBarSettingChangedNotification,
                object: nil
            )

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTerminate),
                name: NSApplication.willTerminateNotification,
                object: nil
            )
        }

        func applicationDockMenu(_: NSApplication) -> NSMenu? {
            let menu = NSMenu()

            let playPauseItem = NSMenuItem(
                title: mpd.status.isPlaying == true ? "Pause" : "Play",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: ""
            )
            playPauseItem.tag = mpd.status.isPlaying == true ? MenuAction.pause.rawValue : MenuAction.play.rawValue
            menu.addItem(playPauseItem)

            let nextItem = NSMenuItem(
                title: "Next song",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: ""
            )
            nextItem.tag = MenuAction.nextSong.rawValue
            menu.addItem(nextItem)

            let previousItem = NSMenuItem(
                title: "Previous song",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: ""
            )
            previousItem.tag = MenuAction.previousSong.rawValue
            menu.addItem(previousItem)

            menu.addItem(NSMenuItem.separator())

            let favoritesItem = NSMenuItem(
                title: "Add current song to favorites",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: ""
            )
            favoritesItem.tag = MenuAction.addToFavorites.rawValue
            menu.addItem(favoritesItem)

            return menu
        }

        private func configureStatusItem() {
            popoverAnchor.button!.sendAction(on: [.leftMouseDown, .rightMouseDown])
            popoverAnchor.button!.action = #selector(handleButtonAction)

            if showStatusBar {
                statusItem.button!.sendAction(on: [.leftMouseDown, .rightMouseDown])
                statusItem.button!.action = #selector(handleButtonAction)
            }

            setPopoverAnchorImage()
        }

        private func configurePopover() {
            popover.behavior = .semitransient
            popover.contentViewController = NSViewController()
            popover.contentViewController!.view = NSHostingView(
                rootView: PopoverView()
                    .environment(mpd)
            )
        }

        func setPopoverAnchorImage(changed: String? = nil) {
            guard showStatusBar else {
                return
            }

            switch changed {
            case "play":
                popoverAnchor.button!.image = NSImage(systemSymbol: .playFill, accessibilityDescription: "play")
            case "pause":
                popoverAnchor.button!.image = NSImage(systemSymbol: .pauseFill, accessibilityDescription: "pause")
            case "stop":
                popoverAnchor.button!.image = NSImage(systemSymbol: .stopFill, accessibilityDescription: "stop")
            case "random":
                popoverAnchor.button!.image = NSImage(systemSymbol: .shuffle, accessibilityDescription: "random")
            case "sequential":
                popoverAnchor.button!.image = NSImage(systemSymbol: .arrowUpArrowDown, accessibilityDescription: "sequential")
            case "repeat":
                popoverAnchor.button!.image = NSImage(systemSymbol: .repeat, accessibilityDescription: "repeat")
            case "single":
                popoverAnchor.button!.image = NSImage(systemSymbol: .return, accessibilityDescription: "single")
            default:
                return popoverAnchor.button!.image = NSImage(systemSymbol: .musicNote, accessibilityDescription: "mmpsp")
            }

            changeImageTask?.cancel()
            changeImageTask = Task {
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else {
                    return
                }

                self.popoverAnchor.button!.image = NSImage(systemSymbol: .musicNote, accessibilityDescription: "mmpsp")
            }
        }

        func setStatusItemTitle() {
            guard showStatusBar else {
                return
            }

            guard showStatusbarSong else {
                statusItem.button!.title = ""
                return
            }

            guard var description = mpd.status.song?.description else {
                statusItem.button!.title = ""
                return
            }

            if description.count > 80 {
                description = String(description.prefix(80)) + "…"
            }

            statusItem.button!.title = description
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
            popover.show(
                relativeTo: popoverAnchor.button!.bounds,
                of: popoverAnchor.button!,
                preferredEdge: .maxY
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
                    try? await ConnectionManager.command().pause(mpd.status.isPlaying)
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
                    try? await ConnectionManager.command().pause(false)
                }
            case .pause:
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().pause(true)
                }
            case .nextSong:
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().next()
                }
            case .previousSong:
                Task(priority: .userInitiated) {
                    try? await ConnectionManager.command().previous()
                }
            case .addToFavorites:
                Task(priority: .userInitiated) {
                    guard let song = mpd.status.song else {
                        return
                    }

                    let isFavorited = mpd.playlists.favorites.contains { $0.url == song.url }

                    if isFavorited {
                        try? await ConnectionManager.command().remove(songs: [song], from: .favorites)
                    } else {
                        try? await ConnectionManager.command().add(songs: [song], to: .favorites)
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
