# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

swmpc is a native MPD (Music Player Daemon) client for macOS and iOS, built with SwiftUI. It's a universal app that provides a modern interface for controlling MPD servers.

- **Platforms**: macOS 26, iOS 26
- **Language**: Swift 6.2
- **UI Framework**: SwiftUI with use of new Observation macro
- **Build System**: Xcode project (no Package.swift)
- **Concurrency**: Uses the modern Swift 6.2 model (Main Actor by default, Approachable Concurrency). See the Concurrency Model section for detailed guidance.

## Concurrency Model

This project adopts Swift 6.2's modern concurrency settings. This fundamentally shifts the project to a "safer-by-default" model where code runs on the main actor unless you explicitly opt-out. Here's what that means in practice:

**1. Default Execution Context: Main Actor by Default**

- **Before**: In older Swift versions, code was non-isolated by default. An `async` function on a plain class would run on a background thread, often leading to unexpected concurrency and data race warnings that required manual `@MainActor` annotations.
- **Now**: Code is **`@MainActor` isolated by default**. Most types and functions will implicitly run on the main thread, eliminating many common data races with the UI. Concurrency is now something you **opt-in** to, not opt-out of.

**2. Offloading Work to a Background Thread**

- **Before**: You would write a `nonisolated async func` to run work on a background thread.
- **Now**: A plain `nonisolated async func` now runs on the *caller's* actor due to "Approachable Concurrency". To explicitly run code on a background thread (the global executor), you must now use the **`@concurrent`** attribute.
  ```swift
  @concurrent
  func performHeavyComputation() async -> Result {
    // This code runs on a background thread.
  }
  ```
  **Guidance**: Use `@concurrent` only for CPU-intensive tasks. Standard `await` calls for network requests do not block the main thread and do not need `@concurrent`.

**3. Handling Protocol Conformances (e.g., `Codable`)**

- **Before**: This was less of an issue because types were not `@MainActor` by default.
- **Now**: Since most types are implicitly `@MainActor`, you may get compiler errors when conforming to protocols like `Codable` that have `nonisolated` requirements. You have two primary solutions:
  - **For background processing**: If you intend to encode/decode on a background thread, make the entire type `nonisolated`.
    ```swift
    // This model can be used on any thread.
    nonisolated struct MyData: Codable { ... }
    ```
  - **For main-thread processing**: If encoding/decoding on the main thread is acceptable, isolate the *conformance* to the main actor.
    ```swift
    // This model is on the MainActor, and its Codable conformance is too.
    struct MyData: @MainActor Codable { ... }
    ```

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

## Key Dependencies

External packages (managed in Xcode):
- `OpenAI`: AI integration
- `SwiftUIIntrospect`: AppKit/UIKit introspection
- `LaunchAtLogin` (macOS only): Startup behavior
- `ButtonKit`: Async button handling

## MPD Protocol Notes

- Requires MPD 0.24+
