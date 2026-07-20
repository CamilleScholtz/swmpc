---
name: localization
description: Read and edit an Xcode String Catalog (.xcstrings) via the bundled l10n.sh script, and apply Apple's localization best practices. Use when adding, updating, searching, renaming, or deleting localization keys or translations; setting plural variants or translator comments; listing keys missing a translation for a language; viewing per-language translation stats; finding unused or stale keys; or writing/reviewing localizable Swift code. String catalogs are usually too large to open with Read/Edit — always go through the scripts.
---

# Localization

The scripts work on any Xcode String Catalog (`.xcstrings`). They auto-discover
the catalog by searching the project for `.xcstrings` files (preferring
`Localizable.xcstrings` when several exist) and can be pointed at a specific
one with the `L10N_FILE` env var. Run `l10n.sh file` to see which catalog is
targeted.

String catalogs are usually too large to open with the Read/Edit tools — use
the scripts instead. They operate on the catalog with `jq`, write changes back
atomically, and re-serialize to Xcode's exact on-disk format (Xcode writes
`"key" : value` with spaces around the colon; without normalization every edit
would produce a huge spurious git diff).

Both scripts resolve the project root from their own location, so they can be
run from any working directory.

## l10n.sh

`.claude/skills/localization/scripts/l10n.sh <command> [args]`

| Command | Purpose |
|---|---|
| `file` | Print the resolved catalog path |
| `keys` | List all translatable keys |
| `search <pattern>` | Search keys (case-insensitive) |
| `search-values <pattern>` | Search translation values; prints `key⇥lang⇥value` |
| `get <key>` | Show all translations for a key (raw JSON) |
| `comment <key> [text]` | Show or set the translator comment for a key |
| `set <key> <lang> <value>` | Set a single translation |
| `set-plural <key> <lang> <cat> <value>` | Set a plural variant (`zero\|one\|two\|few\|many\|other`) |
| `batch-set <file.tsv>` | Bulk set from a TSV file (`key`⇥`lang`⇥`value`), single pass |
| `missing <lang>` | Keys missing **or pending** (state ≠ `translated`) for `<lang>` |
| `stats [lang]` | Per-language translated counts, plus pending/stale totals |
| `stale` | Keys Xcode marked `extractionState: "stale"` (removed from code) |
| `rename <old> <new>` | Rename a key, preserving translations |
| `delete <key> [lang]` | Delete a key, or just one language's translation |
| `normalize` | Re-serialize the file to Xcode's exact `.xcstrings` format |

### Notes

- **Adding a new string:** set the source-language value first (e.g.
  `set "New key" en "New key"`), then other languages, then a translator
  comment (`comment <key> <text>`). Keys are created on first `set`.
- **Bulk translations:** prefer `batch-set` over many `set` calls — it applies
  all rows in one pass. Build a TSV with one `key⇥lang⇥value` row per cell;
  `\n` and `\t` escapes in values become real newlines/tabs.
- **Plurals:** a localization holds either a flat value or variations, never
  both — `set` refuses keys that use variations; use `set-plural`, which also
  converts a flat value to plural form. Fill every category the language
  requires (English: one/other; Russian: one/few/many/other; …).
- **Languages:** use the BCP-47 codes as they appear in the catalog (`en`,
  `de`, `fr`, …). Run `stats` to see which languages exist.
- `set`, `set-plural`, and `batch-set` mark each unit `state: "translated"`.
- **Renaming keys:** Xcode re-extracts strings from code on every build, so
  also update the source references or the old key comes back.

## find_unused_keys.sh

`.claude/skills/localization/scripts/find_unused_keys.sh`

Lists catalog keys not referenced anywhere in the project sources (Swift,
ObjC, storyboards/xibs). Matching accounts for format specifiers (`%@`,
`%lld`, …), Swift string-escape forms, and interpolation; placeholder-only
keys it cannot verify are listed separately. Matching is textual, so keys
built dynamically at runtime are invisible to it — verify each hit, then
remove confirmed-unused keys with `l10n.sh delete <key>`. Cross-check with
`l10n.sh stale` for keys Xcode itself no longer extracts.

## Best practices

Full guidance distilled from Apple's docs lives in
[references/best-practices.md](references/best-practices.md) — consult it when
writing or reviewing localizable Swift code. The short version:

- SwiftUI literals in `Text`/`Label`/etc. are auto-localizable; elsewhere use
  `String(localized:)`, and pass strings around as `LocalizedStringResource`,
  not `String`. In frameworks/packages, pass `bundle: #bundle`.
- Give every string a translator comment describing where it appears and what
  its placeholders are.
- Never concatenate sentence fragments or branch on plural count in code — use
  one key with interpolation, and plural variations for counts.
- Never hand-format user-visible dates, numbers, currencies, measurements, or
  lists — use Foundation's `formatted(…)` styles, which localize per locale.
- Mark brand names and symbols `shouldTranslate: false` instead of deleting
  them; keep unreviewed machine translations in `needs_review` state.
