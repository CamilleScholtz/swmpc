//
//  swmpcApp.swift
//  swmpc
//
//  Created by Camille Scholtz on 08/11/2024.
//

import SwiftUI

@main
struct swmpcApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            AppView()
                .environment(appDelegate.player)
        }
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) static var shared: AppDelegate!

    public var player = Player()

    private lazy var popoverAnchor = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let popover = NSPopover()

    private var changeImageWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_: Notification) {
        AppDelegate.shared = self

        configureStatusItem()
        configurePopover()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    private func configureStatusItem() {
        popoverAnchor.button!.sendAction(on: [.leftMouseDown, .rightMouseDown, .scrollWheel])
        popoverAnchor.button!.action = #selector(buttonAction)

        statusItem.button!.sendAction(on: [.leftMouseDown, .rightMouseDown, .scrollWheel])
        statusItem.button!.action = #selector(buttonAction)

        setPopoverAnchorImage()
    }

    private func configurePopover() {
        popover.behavior = .semitransient
        popover.contentViewController = NSViewController()
        popover.contentViewController!.view = NSHostingView(
            rootView: PopoverView()
                .environment(player)
        )
    }

    public func setPopoverAnchorImage(changed: String? = nil) {
        switch changed {
        case "play":
            popoverAnchor.button!.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "play")
        case "pause":
            popoverAnchor.button!.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: "pause")
        case "random":
            popoverAnchor.button!.image = NSImage(systemSymbolName: "shuffle", accessibilityDescription: "random")
        case "sequential":
            popoverAnchor.button!.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "sequential")
        case "repeat":
            popoverAnchor.button!.image = NSImage(systemSymbolName: "repeat", accessibilityDescription: "repeat")
        case "singe":
            popoverAnchor.button!.image = NSImage(systemSymbolName: "return", accessibilityDescription: "singe")
        default:
            return popoverAnchor.button!.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "mmpsp")
        }

        changeImageWorkItem?.cancel()
        changeImageWorkItem = DispatchWorkItem {
            self.popoverAnchor.button!.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "mmpsp")
        }

        if let workItem = changeImageWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
        }
    }

    public func setStatusItemTitle() {
        guard var description = player.current?.description else {
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

    @objc private func buttonAction(_ sender: NSStatusBarButton?) {
        guard let event = NSApp.currentEvent else {
            return
        }

        // TODO: `case .scrollWheel` doesn't work.
        switch event.type {
        case .rightMouseDown:
            Task(priority: .userInitiated) { @MainActor in
                await player.pause(player.status.isPlaying ?? false)
            }
        default:
            togglePopover(sender)
        }
    }
}
