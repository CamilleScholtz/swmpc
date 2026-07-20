---
description: "Apple Human Interface Guidelines as structured design values — system colors (incl. increased-contrast variants), the full Dynamic Type ramp, Liquid Glass rules and budgets, layout and hit-target metrics, SF Symbols, and HIG-to-SwiftUI component mappings. Use when styling or reviewing any Apple-platform UI: picking a color, size, spacing, corner radius, or hit target; writing .glassEffect / material code; choosing an SF Symbol; or answering 'what does the HIG say about X'."
name: apple-hig
---

Apple refreshed the vivid system color palette on 2025-06-09 (WWDC25 / Liquid Glass). **Model training data predates this and is wrong.** `systemBlue` is `#0088FF`, not `#007AFF`. Never answer a color question from memory — read `references/color.md`.

Values here are provenance-tagged so you know what to trust:

| Tag | Meaning |
|---|---|
| `apple-hig` / `apple-system` | Apple-published fact. |
| `wcag-aa` | The 4.5:1 contrast rule. |
| `figma-effect` / `community-bestpractice` | Useful number Apple never published — a guardrail to confirm, not gospel. |
| `convention` | Common community practice, no Apple source. |
| `verify: true` | Beta-era name or value that shifts between releases; confirm in Xcode before shipping. |

Honest data beats confident data. When a reference says Apple publishes no number, say that rather than inventing one. Never promote a community heuristic to an Apple fact.

## Non-negotiables

1. **Reference colors by name, never by hex.** `Color(.blue)`, `Color(.label)`, `Color(.secondarySystemBackground)` are adaptive — they resolve per light/dark/increase-contrast automatically. Apple explicitly warns values "may fluctuate from release to release." Hex in the references is for design-tool work only; a hardcoded hex in shipping UI is a bug.
2. **Drive type from text styles, not point sizes.** `.font(.body)`, `.font(.headline)`. Hardcoded sizes break Dynamic Type — and Body runs 17 → 53 pt (3.1×) from default to AX5. The point tables are for spec/design work.
3. **Design hit targets to 44×44pt on iOS/iPadOS.** Apple publishes this as the **default** control size; the published **minimum** is 28×28pt — a floor for dense/secondary controls, not a license to shrink. macOS also has published sizes (28×28 default / 20×20 min), so "macOS has no rule" is wrong. Full 5-platform table in `references/layout.md`.
4. **Continuous corners, not circular** — and on iOS 26+ prefer the real concentric APIs (`ConcentricRectangle`, `.containerShape`) over hand-computing `outer = inner + padding`.
5. **Any translucency needs a contrast plan.** Text contrast ≥4.5:1 (≥3:1 at 18pt or bold), measured **after** blur against the real backdrop, in light *and* dark. Never rely on a blur for legibility.
6. **Supply light + dark + increased-contrast variants for every custom color** — even in a single-appearance app. Liquid Glass adaptivity requires them.

## Current OS status (verified 2026-07-20)

iOS 27 / WWDC26 changed **less than you'd assume**. Verified against live HIG change logs:

- **No spec changes** to color, typography, materials/Liquid Glass, layout, or SF Symbols. All Liquid Glass symbols remain `iOS 26.0+`. SF Symbols 7 is still current — there is no SF Symbols 8.
- **Real 2026 changes are confined to components:** tab bars and search fields (2026-06-08), sheets (2026-03-24, new Cancel/Done/Back placement rules), plus new toolbar APIs (`ToolbarMinimizationBehavior` — note the rename from `ToolbarMinimizeBehavior`), `.pickerStyle(.tabs)`, `TabRole.prominent`, and `.textFieldStyle(.bordered)` replacing the now-deprecated `.roundedBorder`.

# References

- `references/color.md`: Use when picking, reviewing, or converting any color — system colors, the gray ramp, or semantic roles. Full post-WWDC25 spec table with **four variants per color** (light, dark, increased-contrast light, increased-contrast dark), the complete semantic role list, and the Liquid Glass color rules (tint sparingly; color the background of a primary action, not its glyph).
- `references/typography.md`: Use when setting fonts, sizes, or weights, or checking a size against the spec. The complete iOS Dynamic Type ramp — 11 styles × 12 categories including AX1–AX5, as size/leading — plus macOS, tvOS, and watchOS ramps, default/minimum sizes per platform, tracking curves, and Apple's explicit large-text layout rules.
- `references/liquid-glass.md`: Use when writing or reviewing `.glassEffect`, `GlassEffectContainer`, materials, blurs, or anything translucent — and when text sits over a photo. Rigorously separates what Apple mandates (qualitative — no blur cap, no layer count) from community/Figma numeric guardrails. Covers the regular/clear/identity variants, the 35% dimming rule for clear glass, scroll edge effects, contrast minimums, and a pre-ship checklist.
- `references/layout.md`: Use when choosing spacing, margins, corner radii, or hit targets. The published 5-platform control-size table (default *and* minimum), the real concentric corner-radius APIs, size classes, and the 8pt grid honestly tagged as convention rather than Apple fact.
- `references/components.md`: Use when building or reviewing a standard control — which SwiftUI API implements a given HIG component, which styles exist, which tokens apply, and the Liquid Glass variant where one exists. Now includes search field, toolbar, sidebar, popover, and action sheet, with deprecated and renamed APIs flagged.
- `references/sf-symbols.md`: Use when a UI needs a glyph. Curated symbol names by role, the four rendering modes, the full `SymbolEffect` list with availability, `.symbolVariant(.fill)`, and the RTL directional rule (`chevron.backward`, never `chevron.left`). A wrong symbol name renders nothing rather than erroring — always confirm in the SF Symbols app for the target OS.
