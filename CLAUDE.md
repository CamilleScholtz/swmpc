# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

swmpc is a native MPD (Music Player Daemon) client for macOS and iOS, built with SwiftUI. It's a universal app that provides a modern interface for controlling MPD servers.

- **Platforms**: macOS 15.0+, iOS 18.0+
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI with Observation framework
- **Build System**: Xcode project (no Package.swift)

## Build Commands

```bash
# Build for debug
xcodebuild -project swmpc.xcodeproj -scheme swmpc -configuration Debug
```

**Note**: Most development is done through Xcode IDE. Dependencies are managed through Xcode's Swift Package Manager integration.

## Architecture

The app follows an MVVM-style architecture using SwiftUI and the Observation framework:

- **swmpc/Models/App/**: App-level managers
  - `NavigationManager`: Handles navigation state
  - `IntelligenceManager`: AI integration for smart playlists
  - `Settings`: User preferences with @AppStorage

- **swmpc/Models/MPD/**: MPD protocol implementation
  - `ConnectionManager`: Lower level TCP connection to MPD
  - `StatusManager`: Manages MPD status updates
  - `LibraryManager`: Manages the media in MPD's database when `source` is set to `.database` , and the queue when `source` is set to `.queue`
  - `MPD`: Main MPD client interface. This class initalizes `ConnectionManager`, `StatusManager`, and `LibraryManager` for both the database and queue sources.

- **Platform Differences**: Use `#if os(iOS)` and `#if os(macOS)` for platform-specific code
  - macOS: Menu bar app with NSStatusItem popover
  - iOS: Tab-based navigation with LNPopupUI for now playing

## Key Dependencies

External packages (managed in Xcode):
- `LNPopupUI-Static` (iOS only): Now playing popup
- `OpenAI`: AI integration
- `SwiftUIIntrospect`: View introspection
- `LaunchAtLogin` (macOS only): Startup behavior
- `ButtonKit`: Async button handling

## MPD Protocol Notes

- Uses MPD's idle command for real-time updates
- Requires MPD 0.24+
- Connection state managed through async streams
- Commands follow MPD protocol format: `command arg1 arg2\n`
