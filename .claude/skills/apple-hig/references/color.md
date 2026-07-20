# Color

Apple **refreshed the vivid system colors on 2025-06-09** (WWDC25 / Liquid Glass). Pre-2025 values in model training data are wrong — `systemBlue` moved from `#007AFF` to `#0088FF`.

Re-verified **2026-07-20** against the live HIG. Change log's latest entry is **2025-12-16** (Liquid Glass guidance only) — **no 2026 / WWDC26 color changes**. All hex below re-derived from the published RGB swatches.

**Hex is reference-only.** Apple states outright: *"Avoid hard-coding system color values… The actual color values may fluctuate from release to release."* Reference by name (`Color(.blue)`, `Color(.label)`) so values resolve per light/dark/increase-contrast automatically. A hardcoded hex in shipping UI does not adapt and is a bug.

## System colors (`src: apple-hig`)

Four published variants per color. IC = Increased Contrast (the Accessibility setting).

| Token | SwiftUI | Light | Dark | IC Light | IC Dark |
|---|---|---|---|---|---|
| systemRed | `.red` | `#FF383C` | `#FF4245` | `#E9152D` | `#FF6165` |
| systemOrange | `.orange` | `#FF8D28` | `#FF9230` | `#C55300` | `#FFA056` |
| systemYellow | `.yellow` | `#FFCC00` | `#FFD600` | `#A16A00` | `#FEDF43` |
| systemGreen | `.green` | `#34C759` | `#30D158` | `#008932` | `#4AD968` |
| systemMint | `.mint` | `#00C8B3` | `#00DAC3` | `#008575` | `#54DFCB` |
| systemTeal | `.teal` | `#00C3D0` | `#00D2E0` | `#008198` | `#3BDDEC` |
| systemCyan | `.cyan` | `#00C0E8` | `#3CD3FE` | `#007EAE` | `#6DD9FF` |
| systemBlue | `.blue` | `#0088FF` | `#0091FF` | `#1E6EF4` | `#5CB8FF` |
| systemIndigo | `.indigo` | `#6155F5` | `#6D7CFF` | `#564ADE` | `#A7AAFF` |
| systemPurple | `.purple` | `#CB30E0` | `#DB34F2` | `#B02FC2` | `#EA8DFF` |
| systemPink | `.pink` | `#FF2D55` | `#FF375F` | `#E7124D` | `#FF8AC4` |
| systemBrown | `.brown` | `#AC7F5E` | `#B78A66` | `#956D51` | `#DBA679` |

**visionOS uses the Default (dark) column** for all system colors.

## Gray ramp (`src: apple-hig`)

iOS / iPadOS. `systemGray` is the base; 2–6 go lighter in Light and darker in Dark. Unchanged by the 2025 vivid refresh. In SwiftUI, `Color.gray` == `systemGray`; **steps 2–6 are UIKit-only** (`UIColor.systemGray2`…) — reach them via `Color(.systemGray3)`.

| Token | Light | Dark | IC Light | IC Dark |
|---|---|---|---|---|
| systemGray | `#8E8E93` | `#8E8E93` | `#6C6C70` | `#AEAEB2` |
| systemGray2 | `#AEAEB2` | `#636366` | `#8E8E93` | `#7C7C80` |
| systemGray3 | `#C7C7CC` | `#48484A` | `#AEAEB2` | `#545456` |
| systemGray4 | `#D1D1D6` | `#3A3A3C` | `#BCBCC0` | `#444446` |
| systemGray5 | `#E5E5EA` | `#2C2C2E` | `#D8D8DC` | `#363638` |
| systemGray6 | `#F2F2F7` | `#1C1C1E` | `#EBEBF0` | `#242426` |

## Semantic roles — use these, don't hardcode

The system resolves each role per appearance. Reach for a role before a palette color. Apple: *"Avoid redefining the semantic meanings of dynamic system colors"* — don't use `separator` as a text color, or `secondaryLabel` as a background.

**Foreground (iOS/iPadOS, `src: apple-hig`):**

| Role | Use for |
|---|---|
| `label` | Primary text |
| `secondaryLabel` | Secondary text |
| `tertiaryLabel` | Tertiary text |
| `quaternaryLabel` | Quaternary text |
| `placeholderText` | Placeholder in controls / text views |
| `separator` | Separator that lets content show through |
| `opaqueSeparator` | Separator that does not |
| `link` | Text that functions as a link |

**Backgrounds — two parallel sets.** Use the **grouped** set with a grouped table view, the **system** set otherwise. Each has primary → tertiary conveying hierarchy: primary for the overall view, secondary for groups within it, tertiary for groups within those.

- System: `systemBackground` · `secondarySystemBackground` · `tertiarySystemBackground`
- Grouped: `systemGroupedBackground` · `secondarySystemGroupedBackground` · `tertiarySystemGroupedBackground`

**Fills:** `systemFill` · `secondarySystemFill` · `tertiarySystemFill` · `quaternarySystemFill`

**Tint:** `tintColor`

**macOS (AppKit)** publishes a separate ~35-role set (`controlAccentColor`, `controlBackgroundColor`, `selectedContentBackgroundColor`, `windowBackgroundColor`, `underPageBackgroundColor`, `keyboardFocusIndicatorColor`, `gridColor`, `headerTextColor`, …). Full list on the HIG Color page under Platform considerations > macOS, and in the Developer palette of the standard Color panel.

## Liquid Glass color (`src: apple-hig`)

Liquid Glass has **no inherent color** — it takes color from the content behind it. Applying color gives it a stained-glass appearance.

- **Apply color sparingly.** Reserve it for elements that benefit from emphasis — status indicators, primary actions.
- **To emphasize a primary action, color the background, not the symbol or text.** This is what the system does for prominent buttons (e.g. Done).
- **Never color multiple controls' backgrounds** in one bar — that's the documented incorrect pattern.
- Small elements (toolbars, tab bars) **auto-adapt light/dark** to the underlying content; symbols and text default to monochrome, going dark over light content and light over dark. Larger elements (sidebars) render more opaque to preserve legibility.
- **Over colorful backgrounds, prefer a monochromatic toolbar/tab bar**, or pick an accent color with strong differentiation. A brand accent color works best when app content is primarily monochromatic.
- Check contrast in the **resting** state (e.g. top of scrollable content), not just mid-scroll.

## Critical adaptivity rule (`src: apple-hig`)

> Even if your app ships in a **single appearance mode**, provide **both** light and dark variants of every custom color — Liquid Glass adaptivity needs them.

Custom colors also need an **increased-contrast variant per appearance**, with meaningfully higher differentiation. System colors already define all four.

## Inclusive color

- Never rely on color **alone** to convey state, interactivity, or essential info — pair with text labels or glyph shapes.
- Color meaning is cultural (red = danger in some cultures, positive in others; the HIG's own example is rising-stock green in English vs red in Chinese).

## Color management

sRGB is safe on most displays; **Display P3** gives richer color on wide-gamut displays — export PNG at 16 bits per channel. P3 generally degrades fine on sRGB, but very similar P3 colors can become indistinguishable and P3 gradients can clip. Supply per-color-space variants in the asset catalog when fidelity matters.

## Verification

HIG > Foundations > Color — `https://developer.apple.com/design/human-interface-guidelines/color` (readable via `https://sosumi.ai/design/human-interface-guidelines/color`). For pixel-exact checks use the Apple Design Resources Figma plugin for the target OS.

Note: HIG "Specifications" tables sometimes render inside JS tab widgets that Markdown extraction drops. If a spec section comes back empty, pull `https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json` and walk the `tabNavigator` nodes. (Color has no such tabs — its two spec tables extract cleanly.)
