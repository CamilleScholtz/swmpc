---
name: localization
description: Read and edit Tripstitch's Localizable.xcstrings translation catalog via the bundled l10n.sh script. Use when adding, updating, searching, renaming, or deleting localization keys or translations; listing keys missing a translation for a language; viewing per-language translation stats; or finding unused keys. The .xcstrings file is too large to open with Read/Edit — always go through the scripts.
---
# Localization

`Tripstitch/Localizable.xcstrings` holds every translatable string. It is too large to open with the Read/Edit tools — use the bundled scripts instead. They operate on the catalog with `jq` and write changes back atomically.

Both scripts resolve the project root from their own location, so they can be run from any working directory.

## l10n.sh

`.claude/skills/localization/scripts/l10n.sh <command> [args]`

| Command | Purpose |
|---|---|
| `keys` | List all translatable keys |
| `search <pattern>` | Search keys (case-insensitive) |
| `get <key>` | Show all translations for a key (raw JSON) |
| `set <key> <lang> <value>` | Set a single translation |
| `batch-set <file.tsv>` | Bulk set from a TSV file (`key`⇥`lang`⇥`value`) |
| `missing <lang>` | List keys missing a translation for `<lang>` |
| `stats [lang]` | Translation counts per language |
| `rename <old> <new>` | Rename a key, preserving translations |
| `delete <key> [lang]` | Delete a key, or just one language's translation |

### Notes

- **Adding a new string:** set the source-language value first (e.g. `set "New key" en "New key"`), then add other languages. Keys are created on first `set`.
- **Bulk translations:** prefer `batch-set` over many `set` calls. Build a TSV with one `key⇥lang⇥value` row per cell and pass the file path.
- **Languages:** use the BCP-47 codes as they appear in the catalog (`en`, `nl`, `de`, `fr`, …). Run `stats` to see which languages exist.
- `set` and `batch-set` mark each unit `state: "translated"`.
- Override the target file with the `L10N_FILE` env var if needed (defaults to `Tripstitch/Localizable.xcstrings`).

## find_unused_keys.sh

`.claude/skills/localization/scripts/find_unused_keys.sh`

Lists translation keys present in the catalog but not referenced anywhere in the Swift sources. It accounts for format specifiers (`%@`, `%lld`, …), string interpolation, and non-ASCII escape forms when matching. Use it to prune dead keys: review the output, then remove confirmed-unused keys with `l10n.sh delete <key>`.
