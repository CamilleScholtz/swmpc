//
//  Delegate.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

#if os(macOS)
    import SFSafeSymbols
#endif

@main
struct Delegate: App {
    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    #if os(iOS)
        let mpd = MPD()
    #endif

    var body: some Scene {
        WindowGroup {
            AppView()
            #if os(iOS)
                .environment(mpd)
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
                Button(appDelegate.mpd.status.isPlaying == true ? "Pause" : "Play") {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().pause(appDelegate.mpd.status.isPlaying)
                    }
                }
                .keyboardShortcut(.space, modifiers: [.command])

                Button("Next Song") {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().next()
                    }
                }
                .keyboardShortcut(.downArrow, modifiers: [.command])

                Button("Previous Song") {
                    Task(priority: .userInitiated) {
                        try? await ConnectionManager.command().previous()
                    }
                }
                .keyboardShortcut(.upArrow, modifiers: [.command])

                Divider()

                Button("Add Current Song to Favorites") {
                    NotificationCenter.default.post(name: .addCurrentToFavoritesNotifaction, object: nil)
                }
                .keyboardShortcut("l", modifiers: [])

                Button("Go to Current Song") {
                    NotificationCenter.default.post(name: .scrollToCurrentNotification, object: true)
                }
                .keyboardShortcut("c", modifiers: [])

                Button("Search") {
                    NotificationCenter.default.post(name: .startSearchingNotication, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])

                Divider()

                Button("Refresh Library") {
                    Task {
                        try? await ConnectionManager.command().update()
                    }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            if let playlists = appDelegate.mpd.queue.playlists {
                CommandMenu("Playlists") {
                    Menu("Load Playlist") {
                        ForEach(playlists) { playlist in
                            Button(playlist.name) {
                                Task {
                                    try? await ConnectionManager.command().loadPlaylist(playlist)
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

        private var changeImageWorkItem: DispatchWorkItem?

        @AppStorage(Setting.showStatusBar) var showStatusBar = true
        @AppStorage(Setting.showStatusbarSong) var showStatusbarSong = true

        func applicationDidFinishLaunching(_: Notification) {
            AppDelegate.shared = self

            if showStatusBar {
                configureStatusItem()
                configurePopover()
            }

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleTerminate),
                name: NSApplication.willTerminateNotification,
                object: nil
            )
        }

        func applicationDockMenu(_: NSApplication) -> NSMenu? {
            let menu = NSMenu()

            menu.addItem(
                withTitle: mpd.status.isPlaying == true ? "Pause" : "Play",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: ""
            )

            menu.addItem(
                withTitle: "Next song",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: ""
            )

            menu.addItem(
                withTitle: "Previous song",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: ""
            )

            menu.addItem(NSMenuItem.separator())

            menu.addItem(
                withTitle: "Add current song to favorites",
                action: #selector(AppDelegate.handleMenuItemAction(_:)),
                keyEquivalent: ""
            )

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
            case "singe":
                popoverAnchor.button!.image = NSImage(systemSymbol: .return, accessibilityDescription: "singe")
            default:
                return popoverAnchor.button!.image = NSImage(systemSymbol: .musicNote, accessibilityDescription: "mmpsp")
            }

            changeImageWorkItem?.cancel()
            changeImageWorkItem = DispatchWorkItem {
                self.popoverAnchor.button!.image = NSImage(systemSymbol: .musicNote, accessibilityDescription: "mmpsp")
            }

            if let workItem = changeImageWorkItem {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
            }
        }

        func setStatusItemTitle() {
            guard showStatusBar, showStatusbarSong else {
                return
            }

            guard var description = mpd.status.song?.description else {
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
                Task(priority: .userInitiated) { @MainActor in
                    try? await ConnectionManager.command().pause(mpd.status.isPlaying)
                }
            default:
                togglePopover(sender)
            }
        }

        @objc private func handleMenuItemAction(_ sender: NSMenuItem) {
            switch sender.title {
            case "Play":
                Task(priority: .userInitiated) { @MainActor in
                    try? await ConnectionManager.command().pause(false)
                }
            case "Pause":
                Task(priority: .userInitiated) { @MainActor in
                    try? await ConnectionManager.command().pause(true)
                }
            case "Next song":
                Task(priority: .userInitiated) { @MainActor in
                    try? await ConnectionManager.command().next()
                }
            case "Previous song":
                Task(priority: .userInitiated) { @MainActor in
                    try? await ConnectionManager.command().previous()
                }
            default:
                break
            }
        }
    }
#endif
