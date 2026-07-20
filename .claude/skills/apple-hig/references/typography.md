# Typography

Re-verified **2026-07-20** against the live HIG. Change log top entry is **December 16, 2025**
("Added emphasized weights to the Dynamic Type style specifications for each platform").
**No 2026 entries — WWDC26 / iOS 27 introduced no documented typography spec changes.**

**Fonts (`src: apple-hig`)**

| Family | Where |
|---|---|
| SF Pro | system font on iOS, iPadOS, macOS, tvOS, visionOS |
| SF Compact | system font on watchOS (SF Compact Rounded in complications) |
| SF Mono | monospace variant of San Francisco |
| New York (NY) | serif; available on all platforms (macOS via Mac Catalyst) |
| SF Arabic / Armenian / Georgian / Hebrew | script variants; rounded variants also exist |

- SF and NY ship as **variable fonts with dynamic optical sizing**. Apple explicitly says you do
  **not** need to pick discrete optical sizes (Text vs Display) — the system interpolates per point
  size. Discrete optical sizes are only for design tools that lack variable-font support.
  (A hardcoded "Display ≥20pt / Text <20pt" split is legacy guidance and no longer what the HIG says.)
- Weights run Ultralight → Black; widths include Condensed and Expanded. `src: apple-hig`
- **Avoid Ultralight, Thin, Light.** Prefer Regular / Medium / Semibold / Bold. `src: apple-hig`
- Access via `Font.Design` — never embed system fonts in the app bundle. `src: apple-hig`

**Drive UI from text styles, not point sizes** (`src: convention`) — `.font(.body)`, `.font(.largeTitle)`.
The tables below are the published resolved values, for spec/design/review work. Hardcoding them in
shipping UI breaks Dynamic Type.

## Default and minimum text sizes (`src: apple-hig`)

Applies to custom fonts too.

| Platform | Default | Minimum |
|---|---|---|
| iOS, iPadOS | 17 pt | 11 pt |
| macOS | 13 pt | 10 pt |
| tvOS | 29 pt | 23 pt |
| visionOS | 17 pt | 12 pt |
| watchOS | 16 pt | 12 pt |

## iOS / iPadOS — default (Large) `src: apple-hig`

| Style | Weight | Size | Leading | Emphasized |
|---|---|---|---|---|
| Large Title | Regular | 34 | 41 | Bold |
| Title 1 | Regular | 28 | 34 | Bold |
| Title 2 | Regular | 22 | 28 | Bold |
| Title 3 | Regular | 20 | 25 | Semibold |
| Headline | Semibold | 17 | 22 | Semibold |
| Body | Regular | 17 | 22 | Semibold |
| Callout | Regular | 16 | 21 | Semibold |
| Subhead | Regular | 15 | 20 | Semibold |
| Footnote | Regular | 13 | 18 | Semibold |
| Caption 1 | Regular | 12 | 16 | Semibold |
| Caption 2 | Regular | 11 | 13 | Semibold |

## iOS / iPadOS — full Dynamic Type ramp `src: apple-hig`

Cells are `size/leading` in points. Weights and emphasized weights are constant across all
categories (see table above). AX1–AX5 are the larger accessibility sizes (Settings > Accessibility >
Display & Text Size > Larger Text).

| Style | xS | S | M | **L** | xL | xxL | xxxL | AX1 | AX2 | AX3 | AX4 | AX5 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Large Title | 31/38 | 32/39 | 33/40 | **34/41** | 36/43 | 38/46 | 40/48 | 44/52 | 48/57 | 52/61 | 56/66 | 60/70 |
| Title 1 | 25/31 | 26/32 | 27/33 | **28/34** | 30/37 | 32/39 | 34/41 | 38/46 | 43/51 | 48/57 | 53/62 | 58/68 |
| Title 2 | 19/24 | 20/25 | 21/26 | **22/28** | 24/30 | 26/32 | 28/34 | 34/41 | 39/47 | 44/52 | 50/59 | 56/66 |
| Title 3 | 17/22 | 18/23 | 19/24 | **20/25** | 22/28 | 24/30 | 26/32 | 31/38 | 37/44 | 43/51 | 49/58 | 55/65 |
| Headline | 14/19 | 15/20 | 16/21 | **17/22** | 19/24 | 21/26 | 23/29 | 28/34 | 33/40 | 40/48 | 47/56 | 53/62 |
| Body | 14/19 | 15/20 | 16/21 | **17/22** | 19/24 | 21/26 | 23/29 | 28/34 | 33/40 | 40/48 | 47/56 | 53/62 |
| Callout | 13/18 | 14/19 | 15/20 | **16/21** | 18/23 | 20/25 | 22/28 | 26/32 | 32/39 | 38/46 | 44/52 | 51/60 |
| Subhead | 12/16 | 13/18 | 14/19 | **15/20** | 17/22 | 19/24 | 21/28 | 25/31 | 30/37 | 36/43 | 42/50 | 49/58 |
| Footnote | 12/16 | 12/16 | 12/16 | **13/18** | 15/20 | 17/22 | 19/24 | 23/29 | 27/33 | 33/40 | 38/46 | 44/52 |
| Caption 1 | 11/13 | 11/13 | 11/13 | **12/16** | 14/19 | 16/21 | 18/23 | 22/28 | 26/32 | 32/39 | 37/44 | 43/51 |
| Caption 2 | 11/13 | 11/13 | 11/13 | **11/13** | 13/18 | 15/20 | 17/22 | 20/25 | 24/30 | 29/35 | 34/41 | 40/48 |

Body goes 17 → 53 pt (3.1×) from default to AX5. Layouts must survive that. `src: apple-hig`

## macOS built-in text styles `src: apple-hig`

macOS does **not** support Dynamic Type — these are fixed. Column is *line height*, not leading.

| Style | Weight | Size | Line height | Emphasized |
|---|---|---|---|---|
| Large Title | Regular | 26 | 32 | Bold |
| Title 1 | Regular | 22 | 26 | Bold |
| Title 2 | Regular | 17 | 22 | Bold |
| Title 3 | Regular | 15 | 20 | Semibold |
| Headline | Bold | 13 | 16 | Heavy |
| Body | Regular | 13 | 16 | Semibold |
| Callout | Regular | 12 | 15 | Semibold |
| Subheadline | Regular | 11 | 14 | Semibold |
| Footnote | Regular | 10 | 13 | Semibold |
| Caption 1 | Regular | 10 | 13 | Medium |
| Caption 2 | Medium | 10 | 13 | Semibold |

macOS also publishes dynamic system font variants to match standard controls:
`NSFont.controlContentFont/labelFont/menuFont/menuBarFont/messageFont/paletteFont/titleBarFont/toolTipsFont/userFont/userFixedPitchFont(ofSize:)`. `src: apple-hig`

## tvOS built-in text styles `src: apple-hig`

Note the different style set — there is no Large Title, and there **is** a Subtitle 1.

| Style | Weight | Size | Leading | Emphasized |
|---|---|---|---|---|
| Title 1 | Medium | 76 | 96 | Bold |
| Title 2 | Medium | 57 | 66 | Bold |
| Title 3 | Medium | 48 | 56 | Bold |
| Headline | Medium | 38 | 46 | Bold |
| Subtitle 1 | Regular | 38 | 46 | Medium |
| Callout | Medium | 31 | 38 | Bold |
| Body | Medium | 29 | 36 | Bold |
| Caption 1 | Medium | 25 | 32 | Bold |
| Caption 2 | Medium | 23 | 30 | Bold |

## watchOS Dynamic Type ramp `src: apple-hig`

Cells are `size/leading`. Style set differs again: **Footnote 1 / Footnote 2**, no Callout, no
Subhead. Weights: Large Title/Title 1–3/Body/Captions/Footnotes = Regular, Headline = Semibold.
Emphasized = Bold for Large Title, Semibold for everything else.

Default category is device-dependent: **S** = 38mm, **L** = 40/41/42mm, **xL** = 44/45/49mm.

| Style | xS | S | L | xL | xxL | xxxL | AX1 | AX2 | AX3 |
|---|---|---|---|---|---|---|---|---|---|
| Large Title | 30/32.5 | 32/34.5 | 36/38.5 | 40/42.5 | 41/43.5 | 42/44.5 | 44/46.5 | 45/47.5 | 46/48.5 |
| Title 1 | 28/30.5 | 30/32.5 | 34/36.5 | 38/40.5 | 39/41.5 | 40/42.5 | 42/44.5 | 43/46 | 44/47 |
| Title 2 | 24/26.5 | 26/28.5 | 28/30.5 | 30/32.5 | 31/33.5 | 32/34.5 | 34/41 | 35/37.5 | 36/38.5 |
| Title 3 | 17/19.5 | 18/20.5 | 19/21.5 | 20/22.5 | 21/23.5 | 22/24.5 | 24/26.5 | 25/27.5 | 26/28.5 |
| Headline | 14/16.5 | 15/17.5 | 16/18.5 | 17/19.5 | 18/20.5 | 19/21.5 | 21/23.5 | 22/24.5 | 23/25.5 |
| Body | 14/16.5 | 15/17.5 | 16/18.5 | 17/19.5 | 18/20.5 | 19/21.5 | 21/23.5 | 22/24.5 | 23/25.5 |
| Caption 1 | 13/15.5 | 14/16.5 | 15/17.5 | 16/18.5 | 17/19.5 | 18/20.5 | 18/20.5 | 19/21.5 | 20/22.5 |
| Caption 2 | 12/14.5 | 13/15.5 | 14/16.5 | 15/17.5 | 16/18.5 | 17/19.5 | 17/19.5 | 18/20.5 | 19/21.5 |
| Footnote 1 | 11/13.5 | 12/14.5 | 13/15.5 | 14/16.5 | 15/17.5 | 16/18.5 | 16/18.5 | 17/19.5 | 18/20.5 |
| Footnote 2 | 10/12.5 | 11/13.5 | 12/14.5 | 13/15.5 | 14/16.5 | 15/17.5 | 15/17.5 | 16/17.5 | 17/19.5 |

watchOS stops at **AX3** — there is no AX4/AX5. Two cells break the ±2.5 leading pattern and are
reproduced exactly as Apple publishes them (likely upstream typos): AX1 Title 2 leading `41`, and
AX2 Footnote 2 leading `17.5`. `src: apple-hig`

## visionOS

Apple publishes **no numeric type ramp for visionOS**. Documented facts only: `src: apple-hig`

- Uses **bolder** versions of the Dynamic Type body and title styles.
- Adds **Extra Large Title 1** and **Extra Large Title 2** for wide, editorial layouts — no sizes published.
- Default 17 pt / minimum 12 pt (see table above).
- Shares the **iOS/iPadOS SF Pro tracking table**.
- Prefer 2D text; default text color is white; bold text that sits on no background; billboard
  text anchored in 3D space.

Drive from text styles and let the platform resolve sizes at runtime.

## Tracking `src: apple-hig`

In a running app the system font adjusts tracking automatically at every point size. These values
matter only for **static mockups** or when compositing text outside the text system.

SF Pro (iOS, iPadOS, visionOS, macOS, tvOS) — subset covering common UI sizes; full table runs
6–96 pt at the source URL:

| pt | 1/1000 em | pt offset |
|---|---|---|
| 11 | +6 | +0.06 |
| 12 | 0 | 0.00 |
| 13 | −6 | −0.08 |
| 15 | −16 | −0.23 |
| 16 | −20 | −0.31 |
| 17 | −26 | −0.43 |
| 20 | −23 | −0.45 |
| 22 | −12 | −0.26 |
| 24 | +3 | +0.07 |
| 28 | +14 | +0.38 |
| 34 | +12 | +0.40 |
| 40 | +10 | +0.37 |
| 80+ | 0 | 0 |

Shape of the other published curves (full tables at source):

| Font | Behaviour |
|---|---|
| SF Pro | positive ≤11 pt, crosses zero at 12, most negative at 17–20 (−0.45), positive again ≥24, zero ≥80 |
| SF Pro Rounded | **positive at every size** 6–76 pt (peaks +0.57 at 8–10 pt), zero ≥80 |
| New York | positive ≤14 pt, zero at 15, negative and monotonically widening thereafter (−1.50 at 96, −4.22 at 240) |
| SF Compact / SF Compact Rounded (watchOS) | positive at small sizes, negative from ~17 pt, reaching −2.62 at 96 pt |

macOS and tvOS publish tracking tables identical to SF Pro apart from a 52/53 pt transposition
(macOS/tvOS: 52 → +0.31, 53 → +0.33; SF Pro iOS: 52 → +0.33, 53 → +0.31). `src: apple-hig`

## Rules Apple states explicitly `src: apple-hig`

- Maintain relative hierarchy and visual distinction of text elements when sizes change.
- Prioritize important content when text size grows — not every element must scale (e.g. tab titles).
- Increase meaningful interface icons with font size; SF Symbols do this automatically.
- Keep truncation minimal at AX sizes; aim to show as much useful text at the largest accessibility
  size as at the largest standard size.
- At large sizes prefer **stacked** layouts over inline (text above secondary items), and reduce
  column count.
- Keep primary elements toward the top of a view at very large font sizes.
- Symbolic traits adjust weight and leading. Loose leading for wide columns / long passages; tight
  leading only where height is constrained — **never tight for 3+ lines**. SwiftUI: `.leading(_:)`.
- Custom fonts must implement Dynamic Type and Bold Text themselves.

## Verification

Canonical source: `https://developer.apple.com/design/human-interface-guidelines/typography`

The Specifications tables are rendered in JS tab widgets and are **dropped by most markdown
scrapers** (including sosumi's extraction, which returns the section headings with empty bodies).
To re-verify, pull the DocC JSON directly and walk `primaryContentSections` for `tabNavigator` →
`tabs[].content` → `table` nodes:

```
curl -sL https://developer.apple.com/tutorials/data/design/human-interface-guidelines/typography.json
```

Apple also ships downloadable Dynamic Type size tables per platform in Apple Design Resources
(`https://developer.apple.com/design/resources/`).
