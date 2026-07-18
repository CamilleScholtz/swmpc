# Reading Build Settings

How to consume `GetTargetBuildSettings` output during a security audit, and how to assemble the audit table that Phases 2–4 of `SKILL.md` rely on.

## Schema

`GetTargetBuildSettings` returns:

```json
{ "buildSettings": [ { "macroName": "...", "evaluatedValue": "...", "value": "...", "targetValue": "..." }, ... ] }
```

Field reference:

- **`macroName`** — setting name (always present).
- **`evaluatedValue`** — fully resolved value after `$(...)` macro expansion. This is what the build actually sees. Use this for audit decisions. May be omitted when the resolved value is empty — treat its absence as an empty string.
- **`value`** — raw, unexpanded value as written in the source (often missing).
- **`targetValue`** — present only when the setting is explicitly set at the **target** level (vs. inherited from project level). Use this to detect per-target overrides.

`value` might hold the default value of the setting — read the xcconfig and pbxproj files directly to see if the value was overridden or it's just the default.

## Filter recipes

If `GetTargetBuildSettings` writes its output to a saved file due to a token limit, run `scripts/filter_build_settings.py` against that file to extract only catalog-relevant settings. Do not read the saved file linearly.

The script lives at `scripts/filter_build_settings.py` (relative to the skill root). It derives its filter regex from `references/settings-and-entitlements-catalog.md` at runtime, so adding settings to the catalog automatically extends the filter. Override with `--regex` if you need a narrower filter.

### Compact `name=value` view

```sh
python3 scripts/filter_build_settings.py <saved-file>
```

### With explicit target-override flag

```sh
python3 scripts/filter_build_settings.py <saved-file> --show-overrides
```

### Only catalog settings NOT at a hardened value

```sh
python3 scripts/filter_build_settings.py <saved-file> --unhardened-only
```

The `--show-overrides` and `--unhardened-only` flags can be combined.

## The audit table

The audit table is a per-(target, catalog macro) view assembled by Phase 1 of `SKILL.md`. Phases 2–4 consume it; nothing else is re-fetched.

### Columns

| Column | Meaning |
|---|---|
| `target` | the target name |
| `macroName` | the catalog setting name |
| `evaluatedValue` | what the build sees (from `GetTargetBuildSettings` JSON) |
| `setAtTargetLevel` | `yes` if `targetValue` is present in the JSON, else `no` |
| `numMatchesInXCConfigs` | count of `*.xcconfig` lines (under project-root) mentioning this macro |
| `numMatchesInPbxproj` | count of `project.pbxproj` lines mentioning this macro |
| `matchLocations` | citations from all sources, joined by `; `. Each entry is either `target` or `<source>:<file>:<line>[,<line>...]` (line numbers grouped per (source, file)). File paths are relative to `<project-root>`. |

### Construction recipe

1. **Per target.** Call `GetTargetBuildSettings`, run `scripts/filter_build_settings.py` over its output, and record `evaluatedValue` and `setAtTargetLevel` per catalog macro.
2. **Project-wide once.** One `XcodeGrep` over `*.xcconfig` and `**/project.pbxproj` using the catalog regex. Group hits by (source, file) and per macro count `numMatchesInXCConfigs` / `numMatchesInPbxproj`; collect the file:line citations into `matchLocations`.
3. **Join.** For each (target, catalog macro), emit one row combining the per-target columns with the project-wide counts and citations.

The catalog regex comes from `references/settings-and-entitlements-catalog.md` (backtick-quoted macro names extracted at runtime); both the script and the project-wide grep share it, so adding a setting to the catalog automatically extends both.

### Predicates

Three named predicates referenced from `SKILL.md`:

- **already hardened** ≡ `evaluatedValue ∈ {YES, YES_AGGRESSIVE, YES_ERROR}`
- **at default OFF** ≡ `evaluatedValue = NO` AND `setAtTargetLevel = no` AND `numMatchesInXCConfigs = 0` AND `numMatchesInPbxproj = 0`
- **deliberately disabled** ≡ `evaluatedValue ∉ {YES, YES_AGGRESSIVE, YES_ERROR}` AND (`setAtTargetLevel = yes` OR `numMatchesInXCConfigs > 0` OR `numMatchesInPbxproj > 0`)

## Inferring product type from the audit table

Use the `MACH_O_TYPE` and `WRAPPER_EXTENSION` to determine the product type from the result of `GetTargetBuildSettings`, and ultimately, if the product supports Pointer Authentication or other capabilities.

| MACH_O_TYPE | WRAPPER_EXTENSION | Product type |
|---|---|---|
| `mh_execute` | `app` | `com.apple.product-type.application` (or `.application.on-demand-install-capable` for app clips) |
| `mh_execute` | `xpc` | `com.apple.product-type.xpc-service` |
| `mh_execute` | `dext` | `com.apple.product-type.driver-extension` |
| `mh_execute` | `systemextension` | `com.apple.product-type.system-extension` |
| `mh_execute` | `appex` | `com.apple.product-type.app-extension` |
| `mh_execute` | `""` (empty) | `com.apple.product-type.tool` |
| `mh_dylib` | `framework` | `com.apple.product-type.framework` |
| `mh_bundle` | `xctest` | `com.apple.product-type.bundle.unit-test` |

An empty `evaluatedValue` for `WRAPPER_EXTENSION` means the target has no wrapper bundle (e.g. a command-line tool); the audit table emits the row regardless. If neither `MACH_O_TYPE` nor `WRAPPER_EXTENSION` matches a row above, treat the target's product type as unknown and skip it for any phase that requires a known supported type.

Cross-reference against the "Supported Product Types" list in `references/enhanced-security.md` when deciding whether a target is eligible for a given capability.
