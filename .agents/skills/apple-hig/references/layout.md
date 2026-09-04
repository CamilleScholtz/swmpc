# Layout

Apple publishes **no numeric spacing scale and no corner-radius scale**. It *does* publish control
sizes, control padding, tvOS safe-area insets, size classes, and device dimensions — those are tagged
`src: apple-hig` below with the real numbers. The 8pt grid and the 8/12/16 radius ladder are community
conventions, tagged as such. Prefer system spacing (default `padding()`, layout margins, safe-area
insets) and the concentric-corner APIs over magic numbers.

## Control sizes (`src: apple-hig`)

From HIG > Foundations > Accessibility > Mobility. Apple publishes **both** a default and a minimum —
these are different numbers, and 44pt is the *default*, not the floor.

| Platform | Default control size | Minimum control size |
|---|---|---|
| iOS, iPadOS | 44×44 pt | 28×28 pt |
| macOS | 28×28 pt | 20×20 pt |
| tvOS | 66×66 pt | 56×56 pt |
| visionOS | 60×60 pt | 28×28 pt |
| watchOS | 44×44 pt | 28×28 pt |

Design to the **default**; treat the minimum as a hard floor for dense/secondary UI only. Apple's
wording: "Strive to meet the recommended minimum control size for each platform."

## Control spacing (`src: apple-hig`)

Apple: "Consider spacing between controls as important as size."

| Element | Padding around it |
|---|---|
| With a bezel | ~12 pt |
| Without a bezel | ~24 pt (around visible edges) |

visionOS additionally: place button **centers at least 60 pt apart** (HIG > Layout > visionOS).

## Spacing (`src: convention`)

Apple publishes no spacing scale. These are community conventions — do not present them as Apple facts.

- **Grid:** 8pt
- **Scale:** 4, 8, 12, 16, 20, 24, 32, 40, 48pt
- **Layout margins:** 16pt compact / 20pt regular — *not* an Apple-published number. Prefer real system
  layout margins and safe-area insets.

**Floating panels:** Apple publishes no numeric inset for floating glass panels or controls above a tab
bar. Use a spacing-scale step (16–24pt) from the screen edge and clear the tab bar via safe-area insets.

## Corner radii

### Concentric corners — real APIs (`src: apple-system`, iOS 26+)

Apple's guidance (Technology Overviews > Adopting Liquid Glass): "the shape of the hardware informs the
curvature, size, and shape of nested interface elements." **Use the APIs, not a manual formula** — they
adapt across devices and sizes without hard-coded values.

| API | Availability | Purpose |
|---|---|---|
| `ConcentricRectangle` | iOS/macOS/tvOS/watchOS/visionOS 26.0+ | Shape whose corners are concentric to the container |
| `Edge.Corner.Style` | 26.0+ | `.concentric`, `.concentric(minimum:)`, `.fixed(_:)` |
| `View.containerShape(_:)` | 26.0+ | Declares the container shape concentric children resolve against |
| `Shape.rect(corners:isUniform:)` | 26.0+ | Shape-convenience equivalent of `ConcentricRectangle` |
| `RoundedRectangularShape` | 26.0+ | Protocol a custom container shape conforms to |
| `RoundedRectangularShapeCorners` | 26.0+ | `.concentric`, `.concentric(minimum:)`, `.fixed(_:)` |
| `GeometryProxy.containerCornerInsets` | 26.0+ | Container corner insets (`RectangleCornerInsets`) |
| `GeometryProxy.concentricCornerRadii` | **27.0+** | Resolved radii only (`RectangleCornerRadii?`) — for custom drawing |
| `GeometryProxy.concentricCornerRadii(in:)` | **27.0+** | Same, for a specified frame |
| UIKit `UIView.cornerConfiguration` / `UICornerConfiguration` | iOS/tvOS/visionOS 26.0+ (no macOS) | UIKit equivalent |
| UIKit `UICornerRadius.containerConcentric(minimum:)` | iOS/tvOS/visionOS 26.0+ | UIKit dynamic radius — call as `.containerConcentric()` |
| AppKit `NSViewCornerRadius.containerConcentric` / `.containerConcentric(_:)` | **macOS 27.0+ Beta** | AppKit dynamic radius |

Default `ConcentricRectangle()` makes **every** corner individually concentric. Corners far from the
container's corners resolve to **zero** (square) — use `.concentric(minimum:)` to guarantee rounding.

```swift
// Sheet-style: fixed top corners, concentric bottom corners (matches Notes' format sheet)
ConcentricRectangle(uniformTopCorners: .fixed(24.0), uniformBottomCorners: .concentric)

// Per-corner control
ConcentricRectangle(
    topLeadingCorner: .concentric(minimum: 12.0),
    topTrailingCorner: .fixed(24.0),
    bottomLeadingCorner: .concentric,
    bottomTrailingCorner: .fixed(0.0)
)

// Custom container must declare its shape for children to resolve against
content.containerShape(RoundedRectangle(cornerRadius: 20))
```

System views (sheets, popovers) provide a container shape automatically. If the container shape does not
conform to `RoundedRectangularShape`, `ConcentricRectangle` falls back to an inset container shape like
`ContainerRelativeShape`.

Uniform initializers compute each corner's radius first, then apply the **largest** to the uniform set.

**Manual fallback** (pre-26 targets only): `outer_radius = inner_radius + padding`.

### Curvature (`src: apple-system`)

`RoundedRectangle(cornerRadius:style:)` takes `RoundedCornerStyle.continuous` (squircle) vs `.circular`.
Prefer the concentric APIs above where available — they subsume the manual choice for nested shapes.

### Common control radii (`src: community-bestpractice`)

small 8pt · medium 12pt · card 16pt · sheet system-managed. **Not Apple-published.** Confirm against the
live component — many system controls use a capsule or a system-managed radius rather than a fixed number.

Note (`src: apple-hig`): under Liquid Glass, sheets have an **increased** corner radius and list/table
sections have an increased corner radius; half sheets are inset from the display edge.

## Safe areas & layout guides (`src: apple-hig`)

A *safe area* is the region not covered by a toolbar, tab bar, or other system views; it also avoids
Dynamic Island and Mac camera housing. A *layout guide* defines a rectangular region for standard margins
and readable width.

| Platform | Published inset |
|---|---|
| tvOS | **60 pt** top/bottom, **80 pt** sides for primary content |
| Others | No published numbers — use the system safe area |

APIs: SwiftUI `SafeAreaRegions`, `GeometryProxy.safeAreaInsets`, `safeAreaBar(edge:alignment:spacing:content:)`;
UIKit `UILayoutGuide`; AppKit `NSLayoutGuide`.

Controls and navigation (sidebars, tab bars) render **on top of** content, not on the same plane. Extend
backgrounds and scrollable content to the display edges. Where content doesn't span the full window, use
`backgroundExtensionEffect()` (SwiftUI) / `UIBackgroundExtensionView` / `NSBackgroundExtensionView`.

## Adaptivity (`src: apple-hig`)

Handle: screen sizes/resolutions/color spaces · orientation · Dynamic Island and camera controls ·
external displays, Display Zoom, resizable iPad windows · Dynamic Type · locale (RTL, formatting, text length).

**Size classes:** `regular` = larger screen or landscape; `compact` = smaller screen or portrait.
SwiftUI `UserInterfaceSizeClass`. All iPads are regular/regular in both orientations. iPhones are
compact-width/regular-height in portrait; in landscape, Max/Plus/Air models become regular-width/compact-height
while standard and Pro (non-Max) models are compact/compact.

**iOS:** support both orientations where practical; avoid full-width buttons (inset from system margins so
they harmonize with hardware curvature); hide the status bar only for media/games.

**iPadOS:** windows resize continuously to a minimum size. Defer switching to a compact view as long as
possible — design full-screen first. Test at halves, thirds, and quadrants. Prefer hiding tertiary columns
(inspectors) as the view narrows. Consider `TabViewStyle.sidebarAdaptable`.

**macOS:** avoid controls at the window's bottom edge; avoid content under the camera housing.

**watchOS:** extend content edge to edge (the bezel provides padding); max ~3 glyph buttons or 2 text
buttons side by side.

## Device dimensions (`src: apple-hig`)

The HIG Layout page carries full tables of iOS/iPadOS point and pixel dimensions and watchOS screen
dimensions. Spot values (portrait, points): iPhone 17 Pro Max & 16 Pro Max 440×956 · iPhone Air 420×912 ·
iPhone 17 / 17 Pro / 16 Pro 402×874 · iPhone 16 393×852 · iPhone 16e 390×844 · iPad Pro 13" 1032×1376 ·
iPad Air 11" / iPad 11" 820×1180 · iPad mini 8.3" 744×1133. Fetch the page for the full table rather than
memorizing it.

## Verification

- HIG > Foundations > Layout: `https://developer.apple.com/design/human-interface-guidelines/layout`
- HIG > Foundations > Accessibility (control sizes & padding):
  `https://developer.apple.com/design/human-interface-guidelines/accessibility`
- SwiftUI `ConcentricRectangle`: `https://developer.apple.com/documentation/swiftui/concentricrectangle`
- Adopting Liquid Glass: `https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass`

Readable mirror for agents: swap the host for `sosumi.ai` (e.g. `https://sosumi.ai/design/human-interface-guidelines/layout`).

**Re-verified 2026-07-20.** HIG Layout change log's most recent entry is **September 9, 2025** (iPhone 17 /
Air / Apple Watch 11 & Ultra 3 specs); the last substantive guidance change was **June 9, 2025** ("Added
guidance for Liquid Glass"). **No 2026 entries — WWDC26 introduced no changes to the HIG Layout page.**
The Accessibility page's change log likewise stops at June 9, 2025. The iOS 27 layout-relevant API
additions found were `GeometryProxy.concentricCornerRadii` and `concentricCornerRadii(in:)` (both 27.0+ Beta);
the rest of the *SwiftUI* concentric-corner surface shipped in 26.0.

Corrections made this pass (previously-stated claims that did not survive verification):

- AppKit `NSViewCornerRadius` is **macOS 27.0+ Beta**, not 26.0+ — AppKit got corner concentricity a year
  after SwiftUI/UIKit. Don't assume the three frameworks shipped it together.
- Swift's `UICornerRadius` exposes **no bare `containerConcentric` property** — only the method
  `containerConcentric(minimum:)`, which Apple's own sample calls as `.containerConcentric()`. (The bare
  spelling `containerConcentricRadius` exists only in the Objective-C interface.)
- Verified verbatim against the HIG this pass: the 12pt/24pt control padding, tvOS 60/80pt safe-area insets,
  visionOS 60pt button-center separation, the control-size table, and all device-dimension spot values.
