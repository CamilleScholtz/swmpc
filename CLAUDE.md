# CLAUDE.md - SWMPC Project Guidelines

## Build Commands
- Build (macOS): `xcodebuild -project swmpc.xcodeproj -scheme swmpc -configuration Debug build`
- Build (iOS): `xcodebuild -project swmpc.xcodeproj -scheme iOS-swmpc -configuration Debug build`
- Run (iOS Simulator): `xcodebuild -project swmpc.xcodeproj -scheme iOS-swmpc -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' run`
- Clean: `xcodebuild -project swmpc.xcodeproj clean`
- Test: `xcodebuild -project swmpc.xcodeproj -scheme swmpc test`
- Test Single File: `xcodebuild -project swmpc.xcodeproj -scheme swmpc test -only-testing:swmpcTests/[TestClassName]`
- Formatting: `swiftformat --swiftversion 6 .`

## Code Style Guidelines

### Formatting & Structure
- 4-space indentation, opening braces on same line, line length < 80 characters
- Actor-based concurrency model with protocol-oriented design and generics
- MVVM architecture with environment-based dependency injection
- One empty line between functions/types for clear separation

### Naming & Types
- Types: UpperCamelCase (ConnectionManager, ArtworkManager)
- Variables/Functions: lowerCamelCase (isPlaying, getStatusData)
- Boolean variables: use "is/has" prefix (isPlaying, hasConnection)
- Granular error enums that conform to LocalizedError with context

### Modern Swift Practices
- Swift 6 with latest language features
- Swift Concurrency (async/await) for asynchronous operations
- Property wrappers (@Environment, @AppStorage, @State)
- Observe model changes with @Environment and observed state macro
- Type-safe enums for state representation
- Extensions to organize related functionality
- Conditional compilation for platform-specific code (#if os(macOS))
- Defensive programming with guard statements and proper error handling
