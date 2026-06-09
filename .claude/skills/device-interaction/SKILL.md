---
name: device-interaction
description: "Verify iOS app behavior on device or simulator via screenshots, UI hierarchy, and touch interactions."
---
# Device Interaction

TRIGGER when: user asks to verify/test/check if the app works on device, after implementing a UI-affecting feature that needs device verification, user says "does it work", "test this", "check on device", user reports UI doesn't work as expected, need to debug touch/interaction issues.
DO NOT TRIGGER when: user asks about unit tests only, build-only requests without device testing, code review without device testing, simulator configuration questions, changes that don't affect UI (e.g. comments, refactors, non-UI logic).

---

# For the Main Agent

**This is a SUBAGENT skill.** Invoke it via the Agent tool when device verification is needed.

```
Agent tool:
- subagent_type: "general-purpose"
- description: "Verify login feature works"
- prompt: "Using the device-interaction skill, verify that the login feature works correctly on session <device-interaction-session>. Launch the app, capture screenshot and UI hierarchy, check that the login button is visible and tappable, and report if the implementation is working correctly."
```

**After implementing a UI-affecting feature, invoke this skill to verify the implementation works on a device.**

## Session Lifecycle

```
DeviceInteractionStartSession (do this early, runs in the background)
  → DeviceInteractionInstallAndRun (after each code change; includes building)
    → DeviceEventSynthesize (interact + observe, repeatable)
  → DeviceInteractionEndSession (when done — keeping sessions open is resource-heavy)
```

## DeviceInteractionStartSession tool

### Device Discovery

When opening a new device interaction session, pass a device identifier to select a device, or omit it to use the current destination. Pass any non-matching value to get a list of available targets.

## DeviceInteractionInstallAndRun tool

### Optional Parameters

- `commandLineArguments` — arguments passed to the app at launch. Use `$(inherited)` as a token to preserve the scheme's existing arguments (e.g. `["$(inherited)", "--reset-state"]` to add an extra argument at the end).
- `environmentVariables` — key/value pairs set in the app's environment at launch. Use `"$(inherited)"` as a key to preserve the scheme's existing environment variables (e.g. `{"$(inherited)": "", "DEBUG_MODE": "1"}`).

Omit both parameters to leave the scheme's arguments and environment unchanged.

**Prefer these parameters over editing the scheme directly.** They are applied only for that one run and have no lasting effect on the user's configuration.

---

# For the Subagent

**ALWAYS** report UI issues that might be caused by code: overlapping or unreadable text, unexpectedly cropped image/text, wrong colors etc.

## DeviceEventSynthesize tool

This tool allows performing an interaction and observing the state of a device.

## Reading Hierarchy Files

The hierarchy files include calculated center positions for each element:

```
UIView {{100, 200}, {50, 30}}, center: {125.0, 215.0}
  UIButton "Login" {{110, 205}, {30, 20}}, center: {125.0, 215.0}
```

- `{100, 200}` - origin position
- `{50, 30}` - width and height
- `center: {125.0, 215.0}` - calculated center point (best for tapping)

**Always prefer the center coordinates for touch events.**

## Interaction Command Syntax

The `interactionCommand` parameter accepts a command syntax:

| Command | Description |
|---|---|
| `t <x> <y> [duration]` | Tap at coordinates with optional hold duration |
| `d <x> <y>` | Double tap |
| `t <x1> <y1> f <x2> <y2> [duration]` | Swipe from (x1,y1) to (x2,y2) |
| `b h/p/u/d [duration]` | Hardware button: h=Home, p=Power, u=VolUp, d=VolDown |
| `sender keyboard kbd <text>` | Type text; **must be the last command in the chain** — all content after `kbd ` is taken verbatim (multiple spaces preserved). For special characters use `\u{XXXX}` Unicode escapes: `\u{000A}` (return/newline), `\u{0009}` (tab) |
| `w duration` | Wait for a duration without any work |
| `orientation faceDown/faceUp/landscapeLeft/landscapeRight/portrait/portraitUpsideDown` | Set device orientation |

**Examples:**
- `"t 100 200"` - Tap at (100, 200)
- `"d 200 300"` - Double tap at (200, 300)
- `"t 200 600 f 200 200 0.3"` - Swipe up (scroll to the content below)
- `"t 200 200 f 200 600 0.3"` - Swipe down (scroll to the content above)
- `"b h"` - Press home button
- `"b h b h"` - Press home button twice to go to the app switcher
- `"b h w 0 b h"` - Wake and unlock a device (non-passcode devices only)
- `"sender keyboard kbd hello world"` - Type text with spaces
- `"sender keyboard kbd hello   world"` - Type text preserving multiple spaces
- `"sender keyboard kbd submit\u{000A}"` - Type text then press Return/submit
- `"w 0.3"` - Wait for 0.3s
- `"orientation landscapeLeft"` - Rotate device to landscape

## Standard Subagent Workflow

Before any interaction, always capture and read the hierarchy (and screenshot). After any interaction, capture again and verify the result. For complex components (like toggles or switches), look at nested elements (like `Switch` or `Slider`) — nearby elements might correspond to the actual control. When done, report findings to the main agent.

- To capture without interacting, use DeviceEventSynthesize with an empty interactionCommand.
- Never guess positions from screenshots alone — always use hierarchy center coordinates.
- If not confident or thumbnail resolution is insufficient, analyze the full-size screenshot.

## Timing and Retries

- **App launch**: After starting a session, the app may take a few seconds to load. Capture the hierarchy and check it has meaningful UI elements before interacting. If the hierarchy is mostly empty or shows a launch screen, capture again before proceeding.
- **After interaction**: If a tap or swipe doesn't produce the expected change, recapture the hierarchy and retry the interaction once (the element may have shifted during an animation). If it still fails after one retry, report the failure rather than retrying indefinitely.
- **Loading states**: If the hierarchy shows a spinner or loading indicator, capture again after a brief pause. Do not interact with elements that are still loading.

## Judging Success vs Failure

When verifying, distinguish between these categories:

- **Functional bug** (always report): element doesn't respond to tap, navigation goes to wrong screen, crash, data not displayed, missing expected UI element.
- **Visual/layout bug** (always report): overlapping text, truncated labels, elements rendered off-screen, wrong colors, broken alignment.
- **Transient state** (do NOT report as bug): loading spinners, brief animations, keyboard appearing/dismissing. Capture again after the transition completes.
- **Unexpected exits** (always report): crashes, application exits. To identify, track process id and capture process's standard output.
- **Expected behavior** (do NOT report as bug): empty states with placeholder text, disabled buttons when form is incomplete, permission dialogs.

## Error Handling

- If application is not visible, retry once, as this might be caused by a slow device.
- If tap target unclear, re-read hierarchy data for correct center coordinates.
- You can inspect runtime logs to troubleshoot. If you suspect timing bugs, suggest to the main agent that temporarily adding `print` statements in the relevant code may help diagnose the issue.
- Report issues back to the main agent with details and suggestions.