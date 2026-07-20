# Materials & Liquid Glass

Two distinct material systems. Do not conflate them.

- **Liquid Glass** — the *functional* layer: bars, controls, sheets, sidebars, tab bars. Floats above content.
- **Standard materials** — the *content* layer: app backgrounds, grouped sections, overlays.

## System materials (`src: apple-system`)

SwiftUI `Material`, lightest to heaviest:

`.ultraThin` · `.thin` · `.regular` · `.thick` · `.ultraThick` · `.bar`

The iOS/iPadOS HIG names **four** standard materials for the content layer: ultra-thin, thin, regular (default), thick (`src: apple-hig`). `.ultraThick` and `.bar` exist in the API but aren't part of that four. `.bar` matches system toolbar styling.

> **Correction (2026-07-20):** earlier revisions of this file listed `chromeMaterial`. That symbol does **not** exist in SwiftUI — it is UIKit's `UIBlurEffect.Style.systemChromeMaterial`. Use `.bar` or `.thick` in SwiftUI.

Pick a level by how much background should read through (`src: apple-hig`):

- Thicker = more opaque = better contrast for text and fine features.
- Thinner = more translucent = preserves context/sense of place.

Choose by **semantic meaning, not apparent color** — system settings change how a material renders (`src: apple-hig`).

## What Apple actually mandates

Apple publishes **no numeric blur-radius cap and no layer count**. The stated rules are qualitative:

1. **Don't use Liquid Glass in the content layer.** It belongs to controls and navigation. Content-layer glass creates "unnecessary complexity and a confusing visual hierarchy." Use standard materials there instead. (`src: apple-hig`)
   - *Documented exception:* content-layer controls with a transient interactive state — `Slider`, `Toggle` — adopt a Liquid Glass appearance while active. System-provided; don't hand-roll it.
2. **Use Liquid Glass effects sparingly.** Standard components adopt it automatically. On custom controls, "limit these effects to the most important functional elements in your app." Overuse distracts from content. (`src: apple-hig`)
3. **Limit concurrent effects for performance.** "Creating too many Liquid Glass effect containers and applying too many effects to views outside of containers can degrade performance." Apple states no number. (`src: apple-system`)
4. **Apply color sparingly.** Glass has no inherent color; it picks up what's behind it. Tint only elements that need emphasis — a primary action, a status indicator. Put color on the *background* of a prominent button, not on its symbol/text. Don't tint multiple controls in one bar. (`src: apple-hig`)
5. **Provide light and dark color variants even in a single-appearance app** — Liquid Glass adaptivity needs both. (`src: apple-hig`)

Everything numeric in the Budgets table below is a community or Figma-derived heuristic. Treat them as guardrails to confirm, not as Apple values, and say so when you cite them.

## Glass variants (`src: apple-hig`)

| Variant | SwiftUI | Use when |
|---|---|---|
| Regular | `.regular` (default) | Default choice. Blurs *and* adjusts backdrop luminosity to protect legibility. Use when the backdrop may cause legibility issues, or the component carries significant text — alerts, sidebars, popovers. Most system components use this. |
| Clear | `.clear` | **Only** over visually rich backgrounds — photos, video — where content prominence matters more. Highly translucent; does no luminosity correction. |
| Identity | `.identity` | Content renders as if no glass were applied. Escape hatch for conditional styling. |

**Clear glass requires a dimming decision** (`src: apple-hig`):

- Underlying content **bright** → add a dark dimming layer at **35% opacity**.
- Underlying content **sufficiently dark**, or using AVKit standard playback controls (which dim themselves) → no dimming layer needed.

> Numeric discrepancy, reported honestly: the HIG says **35%**; the SwiftUI `Glass.clear` reference code sample uses `.black.opacity(0.3)` (**30%**). Both are Apple-published. Prefer 35% from the HIG for design review; either is defensible. Not a community number.

Variant appearance also shifts with the user's **preferred look for Liquid Glass** (a device setting) and with Reduce Transparency / Increase Contrast (`src: apple-hig`). Do not assume a fixed rendering.

## Glass color behavior (`src: apple-hig`)

- Small elements (toolbars, tab bars): system adapts glass between light and dark appearance based on backdrop. Symbols/text default to **monochromatic** — darker over light content, lighter over dark.
- Large elements (sidebars): glass renders **more opaque** to preserve legibility over complex backgrounds.
- Colorful app backgrounds → prefer a monochromatic toolbar/tab bar, or pick an accent with clear differentiation.
- Check the **resting state** (e.g. top of scroll) for legibility, not just mid-scroll.

## Scroll edge effects (`src: apple-system`)

The transition between scrolling content and pinned controls. `ScrollEdgeEffectStyle`:

- `.automatic` — default; system picks per platform/context. Leave it alone unless it demonstrably fails.
- `.soft` — subtle blurred, progressively opaque boundary.
- `.hard` — linear, nearly opaque boundary with a defined edge line.

`.scrollEdgeEffectStyle(_:for:)` to set; `.scrollEdgeEffectHidden(_:for:)` to remove entirely for an edge.

The HIG credits scroll edge effects as part of how the *regular* variant maintains legibility — they blur and reduce opacity of background content (`src: apple-hig`). **Hiding them removes a legibility mechanism.** If you hide one, re-measure contrast.

## Budgets (`src: community-bestpractice` / `figma-effect`, `verify: true`)

Not Apple values. Apple's own limit guidance is qualitative (see "What Apple actually mandates" #2, #3).

| Guardrail | Value | Source |
|---|---|---|
| Max blur radius — iPhone | 40px | community-bestpractice |
| Max blur radius — iPad/Mac | 60px | community-bestpractice |
| Max compositing layers | 4 per screen | community-bestpractice |
| Control depth max | 20 — Figma Glass "Depth" above this harms control readability | figma-effect |
| Frost range | 10–25 — Figma Glass "Frost"; above 30 reads as milky plastic | figma-effect |

## Contrast minimums (`src: apple-hig`)

Apple publishes these directly and states Accessibility Inspector uses WCAG Level AA as its guidance:

| Text size | Weight | Min ratio |
|---|---|---|
| Up to 17 pt | All | **4.5:1** |
| 18 pt | All | 3:1 |
| Any | Bold | 3:1 |

Measure **after blur**, against the real backdrop. Check both light and dark appearances. If the default scheme misses these, Apple requires at minimum a higher-contrast scheme under the **Increase Contrast** setting.

## Text over photos (`verify: true`)

A custom `.glassEffect` loses the 4.5:1 guarantee over a busy or high-contrast photo. Options, best first:

- **(a)** Use `.clear` glass **plus the 35% dark dimming layer** — Apple's documented path for media backdrops (`src: apple-hig`).
- **(b)** Use a heavier standard material (`.thick` / `.bar`) behind the text instead of custom glass.
- **(c)** Lay a legibility scrim between photo and text — linear gradient from `.clear` to a semantic background/fill (e.g. `Color(.systemBackground)`) across the text band.

Then **re-measure contrast after blur**. Never rely on glass alone for legibility over imagery.

## Accessibility settings & fallback

**What Apple actually says** (`src: apple-hig`):

- Glass variants change appearance under Reduce Transparency and Increase Contrast — the system handles this for **standard components** automatically.
- If your default scheme misses the contrast minimums, you **must** ship a higher-contrast scheme for **Increase Contrast**.
- Supply light + dark + increased-contrast variants for every custom color.

**What Apple does not say** (`src: convention`, `verify: true`): the HIG contains no explicit "ship a solid fallback for Reduce Transparency" mandate. But the system only auto-adapts material it controls. For **custom** translucency you built yourself, ship a solid — or near-solid, ~20% opacity over solid — variant and swap at runtime. Read `@Environment(\.accessibilityReduceTransparency)` and `@Environment(\.colorSchemeContrast)`. Treat this as required engineering practice, not as an Apple quote.

## Separation tip (`src: community-bestpractice`)

Keep text and symbols on a layer *above* the glass group. A subtle inner light (white ~30%, blur ~6) helps separation. Prefer vibrancy over raw color values — a custom `foregroundStyle` (other than hierarchical styles like `.secondary`) **disables vibrancy** (`src: apple-system`).

## Pre-ship checklist

- [ ] Glass is on the navigation layer (bars, controls, sheets) — not on main content.
- [ ] Custom glass is limited to the most important functional elements, not sprinkled.
- [ ] `.clear` is used only over photo/video; everywhere else is `.regular`.
- [ ] Every `.clear` surface over bright content has a ~35% dark dimming layer.
- [ ] At most one tinted control per bar; tint is on the background, not the glyph.
- [ ] Multiple glass shapes are inside a `GlassEffectContainer` (perf + morphing).
- [ ] Scroll edge effects left `.automatic` unless justified; if hidden, contrast re-measured.
- [ ] Text contrast ≥ 4.5:1 (≥3:1 at 18pt or bold) measured **after** blur, in light *and* dark.
- [ ] Text and symbols sit above the glass; color comes from vibrancy, not raw values.
- [ ] Custom-color light, dark, and increased-contrast variants all exist.
- [ ] Increase Contrast and Reduce Transparency both verified on device.
- [ ] Blur radius ≤ 40px (iPhone) / ≤ 60px (iPad, Mac). *Community guardrail, verify.*
- [ ] ≤ 4 compositing layers on this screen. *Community guardrail, verify.*

## SwiftUI API

All Liquid Glass symbols are **iOS 26.0+ / macOS 26.0+ / watchOS 26.0+ / tvOS 26.0+**. No availability changed in iOS 27.

```swift
nonisolated func glassEffect(
    _ glass: Glass = .regular,
    in shape: some Shape = DefaultGlassEffectShape()
) -> some View
```

Default shape is a `Capsule`. Glass anchors to the view's bounds *including padding*. Apply `.glassEffect` **after** other appearance-affecting modifiers.

**Configuring** — `Glass` is a value type; chain it:

```swift
.glassEffect()                                   // .regular, Capsule
.glassEffect(in: .rect(cornerRadius: 16))        // custom shape
.glassEffect(.regular.tint(.orange).interactive())
.glassEffect(.clear)                             // + dimming layer, see above
```

`.interactive(_:)` gives touch/pointer response matching system `.glass` buttons. Use a rounded rect rather than `Capsule`/`Circle` for larger components.

**Containers** — required for multiple glass views (best rendering perf + shape blending):

```swift
GlassEffectContainer(spacing: 40) { ... }
```

Container `spacing` controls how eagerly effects merge. Spacing larger than the interior `HStack`/`VStack` spacing makes shapes blend **at rest**, which usually reads as a bug.

**Combining and morphing:**

- `.glassEffectUnion(id:namespace:)` — force several views into one unified effect shape at rest. Good for dynamically created views or views outside a layout container.
- `.glassEffectID(_:in:)` — identity for morph animations across view-hierarchy changes; pair with `@Namespace`.
- `.glassEffectTransition(_:)` with `GlassEffectTransition`:
  - `.matchedGeometry` — default, for effects within the container's spacing.
  - `.materialize` — for effects farther apart than the container spacing, or simpler/custom transitions.
- `glassEffectID` / `glassEffectTransition` only take effect during transitions or animations.

**Button styles:** `.buttonStyle(.glass)` (`GlassButtonStyle`), `.buttonStyle(.glassProminent)` (`GlassProminentButtonStyle` — applies the app accent to the background).

**Related navigation-layer APIs:** `ToolbarSpacer`, `.backgroundExtensionEffect()`, `.tabBarMinimizeBehavior(_:)`, `TabRole.search`, `TabViewBottomAccessoryPlacement`, `.safeAreaBar(edge:alignment:spacing:content:)`.

**iOS 27 / June 2026 additions** — toolbar-layer only, no glass API changes:

- `.visibilityPriority(_:)` on toolbar content — keeps important actions visible as space shrinks; low priority overflows first.
- `ToolbarOverflowMenu` — push secondary actions (archive, delete) straight to overflow.
- `ToolbarItemPlacement.topBarPinnedTrailing` — anchor an item to the top bar's trailing edge.
- `.toolbarMinimizeBehavior(_:for:)` — control toolbar minimization on scroll.
- `TabRole.prominent` — separate trailing position in the tab bar.
- `NavigationTransition.crossFade` — sheet fades in over content.

Confirm exact signatures in Xcode quick-help before shipping.

## Verification

**Re-verified 2026-07-20** against live Apple docs via sosumi.

Change log status at re-verification:

- **HIG > Materials** — latest entry **September 9, 2025** ("Updated guidance for Liquid Glass"). **No 2026 entries.** The Liquid Glass design guidance did not change at WWDC26.
- **HIG > Color** — latest entry **December 16, 2025** ("Updated guidance for Liquid Glass"). No 2026 entries.
- **HIG > Accessibility** — latest entry June 9, 2025.
- **SwiftUI updates (June 2026 section)** — contains **zero** Liquid Glass entries. Every glass symbol remains `iOS 26.0+`. iOS 27 changes in this area are confined to toolbars, tabs, and transitions.

What was stale in the prior revision: `chromeMaterial` listed as a SwiftUI material (it isn't); no `.clear` vs `.regular` variant guidance; no `.identity`; missing the Apple-published 35% dimming figure; missing scroll edge effects; missing `glassEffectUnion`, `GlassEffectTransition`, glass button styles; contrast minimum tagged `wcag-aa` when Apple publishes the table itself; Reduce Transparency fallback tagged `src: apple-hig` when the HIG makes no such explicit statement (retagged `src: convention`).

Sources: HIG > Foundations > Materials · HIG > Foundations > Color (Liquid Glass color) · HIG > Foundations > Accessibility · `/documentation/SwiftUI/Glass` · `/documentation/SwiftUI/View/glassEffect(_:in:)` · `/documentation/SwiftUI/Material` · `/documentation/SwiftUI/ScrollEdgeEffectStyle` · `/documentation/swiftui/applying-liquid-glass-to-custom-views` · `/documentation/updates/swiftui` · WWDC25 "Meet Liquid Glass" (219), "Get to know the new design system" (356).
