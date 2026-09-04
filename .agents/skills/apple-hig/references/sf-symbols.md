# SF Symbols

Curated, stable, widely-available system symbol names grouped by role, plus the verified SwiftUI API surface for rendering, variants, and animation.

**Re-verified against live Apple docs: 2026-07-20.**

## HONEST DATA POLICY — read before using any name below

- **The full symbol catalog is NOT in Apple's documentation.** It lives only in the SF Symbols app (`developer.apple.com/sf-symbols/`). Nothing on the web reproduces it.
- **Availability is gated per OS release.** Apple's own words: *"Symbols and symbol features introduced in a given year aren't available in earlier operating systems."* `src: apple-hig`
- **Every name in the tables below carries `verify: true`.** Confirm the exact string, minimum-OS availability, weight, and rendering-mode support in the SF Symbols app for your deployment target before shipping. A wrong string fails silently at runtime — `Image(systemName:)` renders nothing, it does not throw.
- **Never invent a symbol name.** If you need a glyph and cannot confirm it exists, say so; do not guess a plausible-looking dotted name.
- The API sections (rendering modes, effects, variants) below are verified from live Apple docs and carry hard availability numbers — those you can rely on.

## Usage

```swift
Image(systemName: "house.fill")
Label("Home", systemImage: "house")
```

**Never hardcode a point size** — size the symbol via the surrounding text style. `src: convention`

### Weights and scales `src: apple-hig`

| Axis | Values | Notes |
|---|---|---|
| Weight | 9: ultralight → black | Each maps to a San Francisco font weight; matches adjacent text automatically |
| Scale | `.small`, `.medium` (default), `.large` | Defined relative to SF cap height; set via `.imageScale(_:)` |

Scale adjusts emphasis against adjacent text **without** breaking weight matching at the same point size.

## Rendering modes `src: apple-hig` `src: apple-system`

`.symbolRenderingMode(_:)` — SwiftUI, on `Image` or `View`. Symbols organize paths into primary/secondary/tertiary layers; the mode decides how color maps onto them.

| Mode | Behavior | Use for |
|---|---|---|
| `.monochrome` | One color, all layers | Default; toolbars, lists, dense UI |
| `.hierarchical` | One color, opacity varies per layer | Depth/emphasis from a single accent color |
| `.palette` | One color **per layer** (2+ styles) | Coordinating a symbol with a specific color scheme |
| `.multicolor` | Symbol's intrinsic colors | Semantic color baked in — `leaf` green, `trash.slash` red |

Omitting the modifier lets the system pick the symbol's preferred mode. HIG guidance: **verify legibility per context** — size and background contrast change which mode reads best.

Using system-provided colors keeps symbols adapting to Dark Mode, vibrancy, and accessibility settings automatically.

### Gradients (SF Symbols 7 / iOS 26+) `src: apple-system`

`.symbolColorRenderingMode(_:)` — **iOS 26.0+**, values `.flat` / `.gradient`. Generates a smooth linear gradient from a single source color. Works across all four rendering modes, for system and custom symbols. Renders at any size but **looks best large**.

### Variable color `src: apple-hig`

Represents a value that changes over time — capacity, strength, progress — by lighting up layers as a 0…1 value crosses thresholds. Applies in **any** rendering mode.

```swift
Image(systemName: "speaker.wave.3", variableValue: 0.66)
```

`.symbolVariableValueMode(_:)` — **iOS 26.0+**, values `.color` (opacity per layer, the classic behavior) / `.draw` (varies drawn *length* of each variable layer — "Variable Draw", SF Symbols 7).

HIG rule: **use variable color for change, not for depth.** Depth is `.hierarchical`'s job.

## Variants — prefer `.symbolVariant` over hardcoded names `src: apple-system`

`SymbolVariants` is **iOS 15.0+**. Available: `.none`, `.fill`, `.slash`, `.circle`, `.square`, `.rectangle`. They compose: `.circle.fill`.

```swift
// Idiomatic — one base name, variant from environment.
Label("Fill", systemImage: "heart").symbolVariant(.fill)
Label("Circle Fill", systemImage: "heart").symbolVariant(.circle.fill)

// Also settable directly:
Label("Fill", systemImage: "heart").environment(\.symbolVariants, .fill)
```

**SwiftUI applies `.fill` for you** in `TabView` tab bar items and in `swipeActions(...)` content. Don't hardcode `.fill` names there — it's redundant and fights the environment. `src: apple-system`

Design intent per HIG: outline for toolbars/lists/alongside text; enclosed (`.circle`/`.square`) to improve legibility at small sizes; `.fill` for emphasis, iOS tab bars, swipe actions, and accent-color selection states; `.slash` for unavailable.

## Animation — symbol effects `src: apple-system`

`.symbolEffect(_:options:isActive:)` and `.symbolEffect(_:options:value:)` — **iOS 17.0+**. `.symbolEffectsRemoved(_:)` strips inherited effects. Effects work on **all** symbols, in all rendering modes, weights, and scales, including custom symbols.

Complete effect list from the `SymbolEffect` protocol. **Every availability number below was re-confirmed
against the live `/documentation/symbols/symboleffect` member list on 2026-07-20** — the 17/18/26 split held
exactly, with no reclassifications:

| Effect | Availability | Purpose |
|---|---|---|
| `.appear` | iOS 17.0+ | Gradually emerge into view |
| `.disappear` | iOS 17.0+ | Gradually recede out of view |
| `.bounce` | iOS 17.0+ | One-shot elastic scale; "an action occurred" |
| `.scale` | iOS 17.0+ | Persistent size change (unlike bounce, does not return) |
| `.pulse` | iOS 17.0+ | Opacity varies; ongoing activity |
| `.variableColor` | iOS 17.0+ | Layer opacity in a repeatable sequence; progress/broadcasting |
| `.replace` | iOS 17.0+ | Swap one symbol for another |
| `.automatic` | iOS 17.0+ | Context-sensitive default |
| `.breathe` | iOS 18.0+ | Opacity **and** size; living/ongoing quality |
| `.rotate` | iOS 18.0+ | Whole symbol or by-layer rotation; in-progress |
| `.wiggle` | iOS 18.0+ | Directional back-and-forth; call to action |
| `.drawOn` | **iOS 26.0+** | Draw along guide points, offscreen → onscreen |
| `.drawOff` | **iOS 26.0+** | Draw onscreen → offscreen |

**Magic Replace** (`ReplaceSymbolEffect.MagicReplace`) is the **default** replace animation: smart transition between related shapes — slashes draw on/off, badges appear/disappear independently. Falls back to the down-up replace between unrelated symbols. Introduced with SF Symbols 6. `verify: true` on the exact minimum OS.

`.replace` configurations: **down-up** (default; state change), **up-up** (forward progression), **off-up** (emphasizes the next state).

`SymbolEffectTransition` (**iOS 17.0+**) applies Appear/Disappear/DrawOn/DrawOff as a view transition — `.transition(.symbolEffect)`.

```swift
Image(systemName: "bolt.slash.fill").symbolEffect(.pulse)
Image(systemName: isOn ? "checkmark" : "xmark").symbolEffect(.replace)
Image(systemName: "gear").symbolEffect(.rotate, options: .repeating, isActive: working)
```

HIG restraint rules: apply animations **judiciously** (no hard limit, but too many overwhelm); each animation must serve a clear communicative purpose; match your app's tone.

## Directionality and RTL — IMPORTANT `src: apple-hig`

SF Symbols ships RTL variants and script-localized symbols (Latin, Arabic, Hebrew, Hindi, Thai, Chinese, Japanese, Korean, Cyrillic, Devanagari, Indic numerals). These adapt **automatically** when device language changes — but only if you pick the right name.

**The rule:** use the direction-relative name for anything that means "back/forward in reading order"; use the absolute name **only** when you mean a literal physical direction.

| Intent | Use | Do NOT use |
|---|---|---|
| Navigate back | `chevron.backward` | `chevron.left` |
| Navigate forward / disclosure | `chevron.forward` | `chevron.right` |
| Literal "to the right" (a physical direction, an onscreen area) | `chevron.right` | `chevron.forward` |

`chevron.left` / `chevron.right` do **not** mirror in RTL. A back button built from `chevron.left` points the wrong way in Arabic and Hebrew.

> Provenance (checked 2026-07-20): the **principle** is Apple-published — HIG > Right to left states "a back
> button must point to the right so the flow of screens matches the reading order" and, conversely, "preserve
> the direction of a control that refers to an actual direction or points to an onscreen area." The
> **specific symbol names** in the table above are not spelled out on any HIG or developer-docs page; the
> per-symbol mirroring behavior lives only in the SF Symbols app. `verify: true` on the exact strings.

Related HIG guidance worth applying:
- **Flip** icons showing forward/backward motion (speaker waves emanate from the reading-start side) and icons representing text/reading direction (`doc.plaintext` bars flip alignment).
- **Don't flip** logos, universal marks (checkmark), clocks, or real-world objects that aren't directional. SF Symbols keeps the same backslash for negation in both LTR and RTL.
- **Don't reverse digits** within a number; **do** reverse numeral *order* in progress/rating controls that flip.

## When to use a system symbol vs a custom glyph `src: apple-hig`

Use SF Symbols wherever interface icons appear — toolbars, tab bars, context menus, inline with text. They align with San Francisco across all weights and sizes for free.

Create a custom symbol only when SF Symbols has no equivalent. Then: export a similar symbol's template, match system level-of-detail / optical weight / alignment / perspective, keep it simple + recognizable + inclusive, annotate layers for hierarchy and animation, and supply an accessibility description.

Hard restrictions:
- **You may not use SF Symbols (or confusingly similar images) in app icons, logos, or any trademarked use.**
- Symbols depicting Apple products/features are copyrighted — displayable, **not** customizable (the app badges these with an Info icon).
- Don't design replicas of Apple products.
- Prefer the SF Symbols app's component library over hand-rolling enclosures/badges for custom symbols.

Negative side margins exist for optical horizontal alignment when a symbol carries a badge; name them `left-margin-Regular-M`-style.

---

# Symbol name tables

All entries: `verify: true` — confirm in the SF Symbols app for your deployment target.

**Fill convention** `src: convention`: many glyphs ship a base + `.fill` pair. Use `.fill` for selected tab items and active controls; use the base outline for unselected or idle states. Prefer expressing this with `.symbolVariant(.fill)` rather than writing the `.fill` string, and rely on SwiftUI's automatic fill inside `TabView` and `swipeActions`.

## Navigation

| Role | Symbol |
|---|---|
| back | `chevron.backward` |
| forward | `chevron.forward` |
| up | `chevron.up` |
| down | `chevron.down` |
| close | `xmark` |
| more | `ellipsis` |
| more (circle) | `ellipsis.circle` |
| menu | `line.3.horizontal` |
| disclosure | `chevron.forward` |

> Corrected 2026-07-20: disclosure was `chevron.right`, which does not mirror in RTL.

## Tab bar

| Role | Idle | Selected |
|---|---|---|
| home | `house` | `house.fill` |
| search | `magnifyingglass` | — |
| library | `music.note.list` | — |
| profile | `person.crop.circle` | `person.crop.circle.fill` |
| settings | `gearshape` | `gearshape.fill` |
| favorites | `star` | `star.fill` |
| notifications | `bell` | `bell.fill` |

`TabView` applies `.fill` automatically — supply the base name only.

## Actions

| Role | Symbol |
|---|---|
| add | `plus` |
| add (circle) | `plus.circle.fill` |
| remove | `minus` |
| delete | `trash` |
| edit | `pencil` |
| share | `square.and.arrow.up` |
| confirm | `checkmark` |
| cancel | `xmark` |
| refresh | `arrow.clockwise` |
| favorite | `heart` / `heart.fill` |
| bookmark | `bookmark` / `bookmark.fill` |

## Media

| Role | Symbol |
|---|---|
| play | `play.fill` |
| pause | `pause.fill` |
| stop | `stop.fill` |
| previous | `backward.fill` |
| next | `forward.fill` |
| skip back | `backward.end.fill` |
| skip forward | `forward.end.fill` |
| shuffle | `shuffle` |
| repeat | `repeat` |
| volume | `speaker.wave.2.fill` |
| mute | `speaker.slash.fill` |

`backward`/`forward` are reading-direction-relative and mirror in RTL — correct for transport controls.

## Status

| Role | Symbol |
|---|---|
| success | `checkmark.circle.fill` |
| warning | `exclamationmark.triangle.fill` |
| error | `xmark.circle.fill` |
| info | `info.circle.fill` |
| help | `questionmark.circle` |

## Content

| Role | Symbol |
|---|---|
| calendar | `calendar` |
| clock | `clock` |
| folder | `folder` |
| document | `doc.text` |
| mail | `envelope.fill` |
| send | `paperplane.fill` |
| phone | `phone.fill` |
| camera | `camera.fill` |
| photo | `photo` |
| location | `location.fill` |
| map | `map` |

---

## Version / change-log status `src: apple-hig`

HIG SF Symbols page change log, most recent entries:

| Date | Change |
|---|---|
| July 28, 2025 | Draw animations + gradient rendering (SF Symbols 7) |
| June 10, 2024 | SF Symbols 6 animations and features |
| June 5, 2023 | Animations section added |
| September 14, 2022 | Variable color section added |

**No 2026 entry exists as of 2026-07-20.** The HIG page's newest content is still SF Symbols 7 (iOS 26 / WWDC25: Draw On/Off, Variable Draw, Gradients, Magic Replace enhancements). The SwiftUI "June 2026" updates page lists **no** symbol-related API changes for iOS 27. Treat SF Symbols 7 as the current generation; do not assume an SF Symbols 8 feature set. `verify: true` — recheck the change log and the SF Symbols app release notes before relying on this.
