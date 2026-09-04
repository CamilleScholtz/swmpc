---
name: xcode-control
description: Control the running Xcode session to build, clean, test, run, and inspect build logs or errors via AppleScript. Use as a direct CLI replacement for the Xcode MCP bridge when developing swmpc, widgets, or schemes in an open Xcode workspace.
---

# Xcode Control

Control the running Xcode session directly via AppleScript. This acts as a drop-in replacement for the Xcode MCP tool service, executing builds and actions inside the live Xcode environment without requiring `xcrun mcpbridge`.

## Helper Script

Run commands using `.agents/skills/xcode-control/scripts/xcode.sh`:

```bash
# Check running workspace and active scheme
.agents/skills/xcode-control/scripts/xcode.sh status

# List schemes
.agents/skills/xcode-control/scripts/xcode.sh schemes

# Switch active scheme (swmpc, widget, MPDKit, Shared)
.agents/skills/xcode-control/scripts/xcode.sh scheme widget

# Build active scheme (or pass scheme name)
.agents/skills/xcode-control/scripts/xcode.sh build swmpc
.agents/skills/xcode-control/scripts/xcode.sh build widget

# Inspect build logs or errors
.agents/skills/xcode-control/scripts/xcode.sh logs --errors

# Clean or Run
.agents/skills/xcode-control/scripts/xcode.sh clean
.agents/skills/xcode-control/scripts/xcode.sh run
```

## When to Use

- When Xcode is running with `swmpc.xcodeproj` open.
- When building or verifying the `widget` or `swmpc` schemes without dealing with headless compiler/dependency mismatch issues.
- When checking Xcode diagnostics and build logs after making code changes.
