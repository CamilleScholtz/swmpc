# CLAUDE.md

## Project Overview

swmpc is a native MPD (Music Player Daemon) client for macOS and iOS, built with SwiftUI.

- **Platforms**: macOS 26, iOS 26
- **Language**: Swift 6.2
- **UI**: SwiftUI + Liquid Glass design language
- **Build**: `swmpc.xcodeproj`, scheme: `swmpc`

## Project Structure

```
swmpc/
├── Packages/
│   └── MPDKit/              # Shared MPD client library
├── widget/                  # WidgetKit extension (Now Playing)
├── swmpc/                   # Main app target
└── swmpc.xcodeproj
```

**Targets:**
- `swmpc` — Main app (macOS/iOS)
- `widget` — WidgetKit extension with Now Playing widgets

## Architecture

Entry point: `swmpc/Delegate.swift`. Uses MVVM with SwiftUI.

**Technologies** (use Apple docs MCP for reference):
- Observation framework (`@Observable`, not `ObservableObject`)
- NetworkConnection (not `NWConnection`)
- Approachable Concurrency + MainActor-by-default isolation
- Liquid Glass design language

## Swift 6.2 Concurrency (Approachable Concurrency)

This project uses **MainActor-by-default isolation**. All code runs on the main actor unless explicitly opted out.

**Key rules:**

1. **Background work requires `@concurrent`** — A `nonisolated async func` still runs on the caller's actor. Use `@concurrent` for CPU-intensive work:
   ```swift
   @concurrent
   func processData() async -> Result { /* runs on background thread */ }
   ```
   Note: Network `await` calls don't block and don't need `@concurrent`.

2. **Protocol conformances** — Types are implicitly `@MainActor`, which can conflict with `nonisolated` protocol requirements like `Codable`:
   ```swift
   nonisolated struct MyData: Codable { }      // For background encode/decode
   struct MyData: @MainActor Codable { }       // For main-thread encode/decode
   ```

## MPDKit Package

Located in `Packages/MPDKit/`. Shared library for MPD client functionality used by both the app and widget.

| Component | Purpose |
|-----------|---------|
| **ConnectionManager** | Actor-based TCP connections with generic modes (Idle, Command, Artwork) |
| **MPDTypes** | Shared types: `Song`, `Album`, `Artist`, `Playlist`, `Server`, enums |
| **WidgetServerConfig** | App Groups bridge for sharing server config with widget |

**Connection modes:**
- `IdleMode` — Long-lived connections for event listening
- `CommandMode` — Quick command execution
- `ArtworkMode` — Binary artwork data transfer

### App Components

| Component | Path | Purpose |
|-----------|------|---------|
| **MPD** | `swmpc/Models/MPD/MPD.swift` | Central coordinator; uses idle command for real-time updates |
| **StatusManager** | `swmpc/Models/MPD/StatusManager.swift` | Playback state, current song, volume |
| **DatabaseManager** | `swmpc/Models/MPD/DatabaseManager.swift` | Library queries and search |
| **QueueManager** | `swmpc/Models/MPD/QueueManager.swift` | Playback queue management |
| **PlaylistManager** | `swmpc/Models/MPD/PlaylistManager.swift` | Playlist CRUD operations |
| **ArtworkManager** | `swmpc/Models/MPD/ArtworkManager.swift` | Album artwork fetching and caching |
| **ServerManager** | `swmpc/Models/MPD/ServerManager.swift` | Multi-server configuration |
| **StateManager** | `swmpc/Models/MPD/StateManager.swift` | Loading/connection states |

### App Services

| Service | Path | Purpose |
|---------|------|---------|
| **NavigationManager** | `swmpc/Models/App/NavigationManager.swift` | Cross-view navigation state |
| **IntelligenceManager** | `swmpc/Models/App/IntelligenceManager.swift` | OpenAI smart playlist generation |
| **BonjourManager** | `swmpc/Models/MPD/BonjourManager.swift` | MPD server discovery |
| **Settings** | `swmpc/Models/App/Settings.swift` | User preferences (`@AppStorage`) |

## Widget Extension

Located in `widget/`. Provides Now Playing widgets using WidgetKit.

| Widget | Description |
|--------|-------------|
| **NowPlayingWidget** | Artwork with overlay text (systemSmall, systemMedium) |
| **NowPlayingAltWidget** | Artwork with sidebar thumbnail (systemSmall) |

- Uses `ConnectionManager` from MPDKit
- Reads server config via App Groups (`WidgetServerConfig`)
- 15-minute timeline refresh interval

### Platform Code Style

Prefer shared code. For platform-specific code, use conditional compilation with **iOS first**:

```swift
#if os(iOS)
// iOS-specific
#elseif os(macOS)
// macOS-specific
#endif
```

### Platform Differences

| Area | iOS | macOS |
|------|-----|-------|
| **Entry** (`Delegate.swift`) | Static `mpd` singleton, `WindowGroup` | `AppDelegate` with `NSStatusBar`, `NSPopover`, dock menu, `LaunchAtLogin` |
| **Navigation** (`AppView.swift`) | `TabView` (Albums, Artists, Songs, Playlists); Now Playing/Queue as full-screen covers | `NavigationSplitView` (3-column); Queue as overlay panel |
| **Settings** (`SettingsView.swift`) | Sheet with Connection + Intelligence | Dedicated scene with Connection + Behavior + Intelligence |

## Dependencies

| Package | Purpose | Location |
|---------|---------|----------|
| `MPDKit` | MPD protocol, connections, types | `Packages/MPDKit` (local) |
| `OpenAI` | Smart playlist generation | All |
| `LaunchAtLogin` | Auto-start at login | macOS |
| `ButtonKit` | Async button actions | All |
| `DequeModule` | Connection buffering | MPDKit |
| `Introspect` | UIKit/AppKit access from SwiftUI | All |

## MPD Protocol

- Requires **MPD 0.22+**
- Three connection modes: Idle (listening), Command (execution), Artwork (binary)
- Real-time updates via `idle` command (no polling)
- Binary protocol for album artwork

## MCP Tools

### xcodebuild-mini

Use for building and testing. **Prefer MCP tools over raw `xcodebuild`**.
**IMPORTANT**: Only build when explicitly requested by the user!

### apple-docs

Use to look up Apple APIs, especially for newer frameworks (Observation, NetworkConnection, Liquid Glass). Prefer `search_apple_docs` for API lookup and `get_wwdc_video` for implementation guidance.
