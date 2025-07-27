# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

swmpc is a native MPD (Music Player Daemon) client for macOS and iOS, built with SwiftUI. It's a universal app that provides a modern interface for controlling MPD servers.

- **Platforms**: macOS 26, iOS 26
- **Language**: Swift 6.2
- **UI Framework**: SwiftUI with use of new Observation macro
- **Build System**: Xcode project (no Package.swift)
- **Concurrency**: Uses the modern Swift 6.2 model (Main Actor by default, Approachable Concurrency). See the Concurrency Model section for detailed guidance.

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
  - `MPD`: Main MPD client with command methods
  - `StatusManager`: Manages MPD status updates
  - `LibraryManager`: Manages the media in MPD's database
  - `QueueManager`: Manages the playback queue
  - `PlaylistManager`: Manages MPD playlists
  - `MPD`: Main MPD client interface. This class initalizes `ConnectionManager`, `StatusManager`, `LibraryManager`, `QueueManager`, and `PlaylistManager`.

- **swmpc/Views/**: SwiftUI views organized by feature

- **Platform Differences**: Use `#if os(iOS)` and `#if os(macOS)` for platform-specific code
  - macOS: Menu bar app with NSStatusItem popover
  - iOS: Tab-based navigation with LNPopupUI for now playing

## Concurrency Model

This project uses the modern Swift 6.2 concurrency model enabled in Xcode 26. This fundamentally changes how we write and reason about concurrent code.

The two key settings enabled are:
1.  **Default Actor Isolation:** `MainActor`
2.  **Approachable Concurrency:** `Yes`

Here’s what this means:

### 1. Code is Main Actor by Default

All code is now implicitly isolated to the main actor. This makes our app behave like a single-threaded application by default, reducing complexity and data races.

-   **Previously:** You had to explicitly mark classes and structs with `@MainActor` to ensure UI-related code ran on the main thread.
-   **Now:** Everything is automatically on the main actor. If you need a type to be usable from any thread (e.g., for background processing), you must explicitly mark it as `nonisolated`.

    ```swift
    // This model needs to be decoded on a background thread.
    nonisolated struct MyAPIModel: Codable {
      // ...
    }
    ```

-   **Common Refactor:** When conforming a main-actor type to a protocol like `Codable` or `PersistentModel`, you will face a choice:
    -   Make the entire type `nonisolated` if it needs to be created/used off the main actor.
    -   Isolate only the conformance `struct MyModel: @MainActor Codable` if encoding/decoding is fast and can stay on main.

### 2. `async` Functions Run on the Caller's Actor

The "Approachable Concurrency" setting changes the behavior of `nonisolated async` functions.

-   **Previously:** A `nonisolated async` function would automatically run on a background thread (the global executor).
-   **Now:** A `nonisolated async` function runs on the *caller's* actor. If you call it from the main actor, it stays on the main actor. This is the new `nonisolated(nonsending)` default.

To get the old behavior and explicitly run a function on a background thread, you must now use the `@concurrent` macro.

-   **Use `@concurrent` to offload work:** If you have a long-running, CPU-intensive task (like decoding large JSON), mark that function as `@concurrent` to force it onto a background thread.

    ```swift
    @MainActor
    class MyViewModel {
      func processData() async {
        let data = await fetchData()
        // This decoding is slow, so we make it @concurrent.
        let model = await decode(data)
        // ... update UI with model ...
      }

      // This function now explicitly runs on a background thread.
      @concurrent
      func decode(_ data: Data) async -> MyModel {
        // Heavy decoding logic here
      }
    }
    ```

## Key Dependencies

External packages (managed in Xcode):
- `OpenAI`: AI integration
- `SwiftUIIntrospect`: AppKit/UIKit introspection
- `LaunchAtLogin` (macOS only): Startup behavior
- `ButtonKit`: Async button handling

## MPD Protocol Notes

- Requires MPD 0.24+
