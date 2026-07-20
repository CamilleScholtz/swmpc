# HIG components → SwiftUI

**Re-verified against live Apple docs: 2026-07-20** (iOS 27 beta SDK era; Swift 6.2).

Every SwiftUI symbol below was checked against `developer.apple.com/documentation/SwiftUI/...` on that
date. Symbols marked `verify: true` could **not** be confirmed and must be checked in Xcode quick-help
before use. Availability is noted where a symbol is iOS 27-only (still Beta) or deprecated.

HIG paths are slugs under `https://sosumi.ai/design/human-interface-guidelines/` (canonical:
`developer.apple.com/design/human-interface-guidelines/`).

---

## What changed since the last revision

Corrections to previously-stated claims:

- `.textFieldStyle(.roundedBorder)` is **deprecated** — replaced by `.bordered` (iOS 27). `.squareBorder`
  is deprecated too.
- `ToolbarMinimizeBehavior` / `.toolbarMinimizeBehavior(_:for:)` **no longer resolve** (404). The iOS 27
  name is `ToolbarMinimizationBehavior` / `.toolbarMinimizationBehavior(_:for:)`. Note this is a *different
  symbol* from `.tabBarMinimizeBehavior(_:)`, which still exists unchanged.
- SwiftUI `ButtonRole` has **no `.primary`**. The HIG describes a "Primary" role, but SwiftUI ships
  `.cancel` · `.destructive` · `.close` · `.confirm`. `.primary` exists only as UIKit `UIButton.Role.primary`.

Corrections from the 2026-07-20 adversarial re-verification:

- **`TabRole.search` is iOS 18.0+, not iOS 26.** `TabRole` itself shipped in iOS 18; only `.prominent` is new
  in 27. Previously mislabelled.
- **The `item:` / `error:` alert and confirmation-dialog overloads are iOS 15.0+, not iOS 27.** They are
  back-deployed, so the "iOS 27-only" label was wrong in a way that would have discouraged valid adoption.
- **`GlassBackgroundEffect` & friends are visionOS 2.4+ only** — not an unconfirmed iOS symbol. The former
  `verify: true` tag is resolved; see the Liquid Glass section.
- Beware stale search indexes: `ToolbarMinimizeBehavior` still *appears* in Apple's search results but both
  its type page and modifier page genuinely 404. Confirmed removed; the correction above stands.

HIG pages with 2026 change-log entries: **tab-bars** (Jun 8 2026), **search-fields** (Jun 8 2026),
**sheets** (Mar 24 2026). All other component pages below last changed in 2025 or earlier.

---

## Button — `/buttons`

```swift
Button(action:label:)
Button("Delete", role: .destructive) { … }
```

**Styles:** `.bordered` · `.borderedProminent` · `.plain` · `.accessoryBar` · `.accessoryBarAction`

**Roles (`src: apple-system`):** `.cancel` · `.destructive` · `.close` · `.confirm`.
No SwiftUI `.primary` role — HIG's "primary" maps to a prominent *style*, not a role.

**Liquid Glass (`src: apple-system`, iOS 26+):** `.buttonStyle(.glass)` secondary ·
`.buttonStyle(.glassProminent)` primary · `.buttonStyle(.glass(_:))` takes a `Glass` config.
Concrete types: `GlassButtonStyle`, `GlassProminentButtonStyle`.

**Sizing (`src: apple-system`):** `.buttonSizing(_:)` with `ButtonSizing.automatic` / `.fitted` / `.flexible`.

**Tokens:** systemBlue (tint) · 44×44pt hit region (visionOS 60×60) · headline (label)

## Navigation bar — `/navigation-bars`

```swift
NavigationStack { … }.toolbar { … }
```

Large title: `.navigationBarTitleDisplayMode(.large)` — iOS 14+, **not available on macOS**.

**Liquid Glass:** minimize the nav bar on scroll with
`.toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)` (iOS 27+).

**Tokens:** largeTitle · system materials (bar background)

## Tab bar — `/tab-bars`

```swift
TabView { Tab(…) { … } }
```

**Liquid Glass (`src: apple-system`):** applied to `TabView` automatically, with scroll-edge effects.
`.tabBarMinimizeBehavior(_:)` takes `TabBarMinimizeBehavior.automatic` / `.never` / `.onScrollDown` /
`.onScrollUp`. **Minimizing is iPhone-only.**

**Roles (`src: apple-system`):** `TabRole.search` (**iOS 18.0+**, not 26 — `TabRole` itself shipped in 18)
marks the tab that implements search · `TabRole.prominent` (iOS 27 Beta) gives one tab prominent visual
treatment; only one tab can have it, and a `.search` tab receives it by default when none is set explicitly.

**iPad styles:** `.tabViewStyle(.tabBarOnly)` · `.sidebarAdaptable` · `.grouped`.
Customization via `.tabViewCustomization(_:)` + `TabViewCustomization`.

**Accessory:** `TabViewBottomAccessoryPlacement` adapts accessory content to its placement.

**Tokens:** systemBlue (selected) · liquid glass

## List — `/lists-and-tables`

```swift
List { … }
```

**Styles:** `.plain` · `.insetGrouped` · `.grouped` · `.inset` · `.sidebar`

**Reordering (iOS 27, `src: apple-system`):** `.reorderable()` on `DynamicViewContent` and
`.reorderContainer(for:isEnabled:move:)` — works in lists, stacks, grids, and custom layouts.

**Swipe actions:** `.swipeActions(edge:allowsFullSwipe:content:)`; iOS 27 adds
`.swipeActions(edge:allowsFullSwipe:content:onPresentationChanged:)` and `.swipeActionsContainer()`,
which extend swipe actions beyond `List` to scroll views, stacks, and grids.

**Tokens:** semantic colors (background, separator) · spacing

## Sheet — `/sheets`

```swift
.sheet(isPresented:) { … }
.sheet(item:onDismiss:content:)
```

Detents: `.presentationDetents([.medium, .large])` · sizing: `.presentationSizing(.form)` / `.page`.
Transition: `.navigationTransition(.crossFade)` fades a sheet in over content (iOS 27).

**HIG (Mar 24 2026 update):** Cancel on the leading edge of the top toolbar, Done on the trailing edge.
Always pair Done with Cancel *or* Back — never ship Done alone, and never show Cancel + Done + Back together.

**Tokens:** continuous radii · system materials

## Text field — `/text-fields`

```swift
TextField(_:text:)
SecureField(_:text:)   // sensitive input
```

**Styles:** `.automatic` · `.bordered` (iOS 27; shape follows `.buttonBorderShape`) · `.plain`
**Deprecated:** `.roundedBorder`, `.squareBorder` — migrate to `.bordered`.

**Tokens:** body · 44pt hit target · semantic colors (`label`; placeholder = `secondaryLabel`; `separator`)

## Toggle — `/toggles`

```swift
Toggle(_:isOn:)
```

**Styles:** `.automatic` · `.switch` · `.button` · `.checkbox` (macOS)

**Tokens:** systemGreen (default on-state; override with `.tint`) · 44pt hit target

## Picker — `/pickers`

```swift
Picker(_:selection:) { … }
```

**Styles:** `.automatic` · `.menu` · `.segmented` · `.wheel` · `.inline` · `.navigationLink` ·
`.palette` · `.radioGroup` (macOS) · `.tabs` (iOS 27)
**Deprecated:** `PopUpButtonPickerStyle`.

**Tokens:** body · systemBlue (selection/tint) · 44pt hit target

## Segmented control — `/segmented-controls`

```swift
Picker(_:selection:) { … }.pickerStyle(.segmented)
```

**iOS 27 alternative:** `.pickerStyle(.tabs)` — visually identical to `.segmented` on iOS/tvOS/visionOS,
but VoiceOver announces options as *tabs*, and macOS renders it distinctly from value selection.
Use `.tabs` when the picker switches views; `.segmented` when it selects a value.

**HIG limits:** ≤5 segments on iPhone, ≤5–7 on wider interfaces. Don't mix text and icons in one control.

**Tokens:** subheadline · semantic colors (background) · 44pt hit target

## Slider — `/sliders`

```swift
Slider(value:in:step:)
```

Tick marks appear automatically when you supply `step` (iOS 26+).
`ProgressView(value:)` for non-interactive progress.

Apple publishes no track or thumb metrics; the thumb and its row honor the 44pt hit target. Tint the
active track with `.tint` — there is no dedicated "progress" semantic color role.

**Tokens:** systemBlue (`.tint`, active track) · 44pt hit target (thumb + row)

## Stepper — `/steppers`

```swift
Stepper(_:value:in:step:)
```

**Tokens:** body (label) · 44pt hit target

## Menu — `/menus`

```swift
Menu(_:) { Button… }
```

Long-press / right-click via `.contextMenu { … }`.

**Tokens:** body · system materials (menu background) · continuous radii

## Alert — `/alerts`

```swift
.alert(_:isPresented:) { Button… } message: { … }
.alert(_:item:actions:)              // iOS 15.0+ — drive from optional data
.alert(error:actions:message:)       // iOS 15.0+ — drive from a LocalizedError
```

Note: the `item:` and `error:` alert overloads are documented as **iOS 15.0+**, *not* iOS 27 — they are
back-deployed, so you can adopt them without raising your deployment target. `alert(error:)` requires
`E: LocalizedError` and uses the error's `errorDescription` as the title.

**HIG:** up to three buttons. Default button trailing (row) or top (stack); Cancel leading or bottom.
Avoid "OK" unless the alert is purely informational.

**Tokens:** headline (title) · body (message) · systemBlue (default action) · systemRed (destructive,
via `Button(role: .destructive)`)

## Action sheet — `/action-sheets`

```swift
.confirmationDialog(_:isPresented:titleVisibility:actions:message:)
.confirmationDialog(_:item:titleVisibility:actions:)   // iOS 15.0+ (not iOS 27), back-deployed
```

Use instead of an alert to offer choices related to an action the person deliberately took.

**Tokens:** body · system materials · systemRed (destructive)

## Progress — `/progress-indicators`

```swift
ProgressView(value:total:)   // determinate
ProgressView()               // indeterminate spinner
```

**Styles:** `.automatic` · `.linear` · `.circular`

No dedicated "progress" semantic color — tint the bar with a system color via `.tint`.

**Tokens:** systemBlue (`.tint`)

---

# Additional components

## Search field — `/search-fields`

```swift
.searchable(text:placement:prompt:)                    // iOS 16+
.searchable(text:isPresented:placement:prompt:)
.searchable(text:tokens:placement:prompt:token:)       // scope tokens
.searchFocused(_:equals:)
```

Placement via `SearchFieldPlacement`. Scoping: see `Scoping a search operation`.

**HIG (Jun 8 2026 update):** three iOS entry points — as a **tab** (`TabRole.search`; standard tab gives a
landing page, button appearance focuses the field immediately), in a **toolbar** (prefer bottom when
there's room), or **inline** with content. iPad/macOS: trailing edge of the toolbar, or top of the sidebar.

**Tokens:** body · system materials · 44pt hit target

## Toolbar — `/toolbars`

```swift
.toolbar { ToolbarItem(placement: .topBarTrailing) { … } }
ToolbarSpacer(…)                       // visual break between Liquid Glass groups
```

**Placements:** `.topBarLeading` · `.topBarTrailing` · `.bottomBar` · `.primaryAction` ·
`.topBarPinnedTrailing` (iOS 27 — anchors an item to the trailing edge even as others overflow).

**Overflow (iOS 27, `src: apple-system`):** `.toolbarOverflowMenu(content:)` + `ToolbarOverflowMenu` push
secondary actions straight to the overflow menu. `ToolbarContent.visibilityPriority(_:)` keeps important
items visible longest as space shrinks.

**Minimization (iOS 27):** `.toolbarMinimizationBehavior(_:for:)` with `ToolbarMinimizationBehavior`
(`.automatic` / `.never` / `.onScrollDown` / `.onScrollUp`); also
`.toolbarMinimizationRestoration(_:for:)` and `.toolbarMinimizationSafeAreaAdjustment(_:for:)`.

**HIG:** aim for ≤3 groups. Prefer unbordered SF Symbols. Keep text-labeled buttons in separate groups so
they don't read as one control. Don't add an overflow menu manually — the system inserts one. Reduce
custom toolbar backgrounds; use `ScrollEdgeEffectStyle` to separate bar from content.
One prominent primary action only, on the trailing side — in SwiftUI use `.buttonStyle(.glassProminent)`
(`.prominent` as a *bar-button style* name is UIKit `UIBarButtonItem.Style.prominent`; there is no
verified SwiftUI `PrimitiveButtonStyle.prominent`) `verify: true`.

**Tokens:** system materials · continuous radii concentric with bar corners

## Sidebar / split view — `/sidebars`

```swift
NavigationSplitView { sidebar } detail: { … }                    // 2 columns
NavigationSplitView { sidebar } content: { … } detail: { … }     // 3 columns
NavigationSplitView(columnVisibility: $vis) { … } detail: { … }
NavigationSplitView(preferredCompactColumn: $col) { … } detail: { … }
```

iOS 16+. Collapses to a stack at compact widths. `NavigationSplitViewVisibility` controls columns;
`NavigationSplitViewColumn` picks the collapsed top column.

**Styles:** `.navigationSplitViewStyle(_:)` · widths via `.navigationSplitViewColumnWidth(min:ideal:max:)`.
Adds a `sidebarToggle` toolbar item automatically — remove with `.toolbar(removing:)`.

Use `NavigationSplitView` (not `TabView`) when you want a sidebar with **no** tab-bar conversion.

**Tokens:** system materials · semantic colors

## Popover — `/popovers`

```swift
.popover(isPresented:attachmentAnchor:arrowEdge:content:)
```

**Tokens:** system materials · continuous radii

---

# Liquid Glass primitives (`src: apple-system`)

```swift
nonisolated func glassEffect(
    _ glass: Glass = .regular,
    in shape: some Shape = DefaultGlassEffectShape()
) -> some View
```

iOS 26.0+. Default shape is a **capsule** (`DefaultGlassEffectShape`); the material fills the view's
bounds *including* padding. Confirmed signature.

**Companions:** `GlassEffectContainer(spacing:content:)` merges shapes so they can morph ·
`.glassEffectID(_:in:)` · `.glassEffectUnion(id:namespace:)` · `.glassEffectTransition(_:)` with
`GlassEffectTransition.identity` / `.materialize` / `.matchedGeometry` · `Glass.interactive(_:)`.

**`glassBackgroundEffect` is visionOS-only — do not confuse it with `glassEffect`.** The
`GlassBackgroundEffect` protocol is **visionOS 2.4+** (no iOS/macOS availability at all), with conforming
types `AutomaticGlassBackgroundEffect`, `FeatheredGlassBackgroundEffect`, and `PlateGlassBackgroundEffect`,
selected via `.automatic` / `.feathered` / `.feathered(padding:softEdgeRadius:)` / `.plate` and applied with
`.glassBackgroundEffect(_:in:displayMode:)`. Reaching for these on iOS is a compile error — the iOS 26+
Liquid Glass entry point is `.glassEffect(_:in:)` above.

**Scroll edges:** `.scrollEdgeEffectStyle(_:for:)` · `.backgroundExtensionEffect()`.

**HIG:** prefer the system's monochromatic treatment when your content layer is already colorful — avoid
tinting control labels similarly to content backgrounds. See `/color#Liquid-Glass-color`.
