# swmpc

Native MPD (Music Player Daemon) client for macOS and iOS (macOS 27.0+, iOS 27.0+).

## Project Structure

- `swmpc/`: Main macOS and iOS SwiftUI application.
  - `Views/`: SwiftUI views (Content, Controls, Detail, Popover, Settings).
  - `Models/`: State management, MPD connection manager (`MPD.swift`), streaming, navigation.
  - `Intents/`: App Intents and App Shortcuts.
  - `Localizable.xcstrings`: Localization string catalog.
- `widget/`: WidgetKit extension (widgets for macOS desktop and iOS Home/Lock screens).
- `Packages/MPDKit/`: Core Swift package implementing the MPD client protocol (0.21+ floor).
- `Packages/Shared/`: Shared models and configurations across targets.

## Commands

### Xcode Session (Recommended when Xcode is open)
Use the `xcode-control` skill script (`.agents/skills/xcode-control/scripts/xcode.sh`) to drive the open Xcode workspace directly without MCP bridge:
- Check status: `.agents/skills/xcode-control/scripts/xcode.sh status`
- Build target: `.agents/skills/xcode-control/scripts/xcode.sh build swmpc` (or `widget`)
- View errors: `.agents/skills/xcode-control/scripts/xcode.sh logs --errors`
- Clean / Run: `.agents/skills/xcode-control/scripts/xcode.sh clean` / `run`

### Headless CLI
- **Run MPDKit tests**:
  ```bash
  swift test --package-path Packages/MPDKit
  ```
- **Build macOS app target**:
  ```bash
  xcodebuild -scheme swmpc -destination 'generic/platform=macOS' build CODE_SIGNING_ALLOWED=NO -quiet
  ```

## Conventions

- **State & Concurrency**: Use Swift Observation (`@Observable`) and modern async/await. Keep views declarative and delegate operations to models.
- **Platform Separation**: Isolate platform-specific frameworks and UI using `#if os(macOS)` and `#if os(iOS)` (e.g. `AppKit` is macOS-only).
- **SF Symbols**: Use type-safe symbols via `SFSafeSymbols` (`Image(systemSymbol: ...)`), avoid stringly-typed system names.
- **Localization**: Localize user-facing copy using `LocalizedStringResource` and update `swmpc/Localizable.xcstrings`.
- **MPD Protocol**: Protocol floor is 0.21. Gate commands and tag narrowing behind protocol version checks when requiring newer MPD releases (e.g., 0.22, 0.24).
- **Testing**: Run MPDKit tests and verify build targets succeed before submitting changes.
