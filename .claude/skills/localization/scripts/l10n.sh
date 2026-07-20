#!/bin/bash
# l10n.sh — Read/edit an Xcode String Catalog (.xcstrings) with jq.
# Usage: l10n.sh <command> [args]
#
# Lives at .claude/skills/localization/scripts/l10n.sh. The project root is
# resolved from this script's own location so it works from any directory.
# The catalog is auto-discovered (see discover_catalog) or set via $L10N_FILE.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

command -v jq >/dev/null 2>&1 || { echo "error: jq is required" >&2; exit 1; }

# Resolve the target catalog: $L10N_FILE wins; otherwise search the project for
# .xcstrings files (skipping build/dependency dirs). A single hit is used
# directly; with several, a sole Localizable.xcstrings is preferred.
discover_catalog() {
  if [ -n "${L10N_FILE:-}" ]; then
    [ -f "$L10N_FILE" ] || { echo "error: L10N_FILE not found: $L10N_FILE" >&2; exit 1; }
    printf '%s\n' "$L10N_FILE"
    return
  fi
  local candidates=()
  while IFS= read -r f; do candidates+=("$f"); done < <(
    find "$PROJECT_ROOT" \
      \( -name .git -o -name .build -o -name DerivedData -o -name Pods \
         -o -name Carthage -o -name .swiftpm -o -name node_modules \) -prune \
      -o -name '*.xcstrings' -print 2>/dev/null | sort
  )
  if [ ${#candidates[@]} -eq 0 ]; then
    echo "error: no .xcstrings file found under $PROJECT_ROOT (set L10N_FILE)" >&2
    exit 1
  fi
  if [ ${#candidates[@]} -eq 1 ]; then
    printf '%s\n' "${candidates[0]}"
    return
  fi
  local localizables=()
  local f
  for f in "${candidates[@]}"; do
    [ "$(basename "$f")" = "Localizable.xcstrings" ] && localizables+=("$f")
  done
  if [ ${#localizables[@]} -eq 1 ]; then
    printf '%s\n' "${localizables[0]}"
    return
  fi
  echo "error: multiple string catalogs found; set L10N_FILE to pick one:" >&2
  printf '  %s\n' "${candidates[@]}" >&2
  exit 1
}

FILE="$(discover_catalog)"

# Re-serialize the catalog in Xcode's exact .xcstrings format. jq (and most JSON
# tools) emit "key": value, but Xcode writes "key" : value (spaces around the
# colon). Without this, every mutating command rewrites every colon line and
# produces a useless multi-thousand-line git diff. Python's json with
# separators=(",", " : "), indent=2, ensure_ascii=False (UTF-8, unescaped
# slashes) and NO trailing newline is byte-identical to Xcode's output. Key
# order is preserved (Python dicts keep insertion order); a brand-new key lands
# at the end rather than in Xcode's sort position, which Xcode fixes on next save.
normalize_xcstrings() {
  command -v python3 >/dev/null 2>&1 || {
    echo "warning: python3 not found; skipping Xcode-format normalization" >&2
    return 0
  }
  python3 - "$1" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False, separators=(",", " : "))
PY
}

# Run a jq mutation atomically: write to a temp file, move into place only on
# success, then re-normalize. On failure the catalog is left untouched.
apply_jq() {
  local tmp="${FILE}.tmp"
  if jq "$@" "$FILE" > "$tmp"; then
    mv "$tmp" "$FILE"
    normalize_xcstrings "$FILE"
  else
    rm -f "$tmp"
    echo "error: edit failed; catalog left unchanged" >&2
    exit 1
  fi
}

key_exists() {
  jq -e --arg k "$1" '.strings | has($k)' "$FILE" >/dev/null
}

require_key() {
  key_exists "$1" || { echo "error: key not found: \"$1\"" >&2; exit 1; }
}

case "${1:-}" in

  # Print the resolved catalog path (also used by sibling scripts)
  file)
    printf '%s\n' "$FILE"
    ;;

  # List all translatable keys (one per line)
  keys)
    jq -r '.strings | to_entries[] | select(.value.shouldTranslate != false) | .key' "$FILE" | sort
    ;;

  # Search keys matching a pattern (case-insensitive grep)
  search)
    [ -z "${2:-}" ] && { echo "Usage: $0 search <pattern>" >&2; exit 1; }
    jq -r '.strings | to_entries[] | select(.value.shouldTranslate != false) | .key' "$FILE" \
      | sort | grep -i -- "$2" || { echo "No keys match '$2'" >&2; exit 1; }
    ;;

  # Search translation values (case-insensitive substring); prints key⇥lang⇥value
  search-values)
    [ -z "${2:-}" ] && { echo "Usage: $0 search-values <pattern>" >&2; exit 1; }
    OUT=$(jq -r --arg p "$2" '
      ($p | ascii_downcase) as $needle
      | .strings | to_entries[] | .key as $k
      | (.value.localizations // {}) | to_entries[] | .key as $loc
      | [.value | .. | objects | select(has("stringUnit")) | .stringUnit.value // empty]
      | .[]
      | select(ascii_downcase | contains($needle))
      | [$k, $loc, .] | @tsv
    ' "$FILE")
    [ -n "$OUT" ] && printf '%s\n' "$OUT" || { echo "No values match '$2'" >&2; exit 1; }
    ;;

  # Get translations for a specific key (all languages, raw JSON)
  get)
    [ -z "${2:-}" ] && { echo "Usage: $0 get <key>" >&2; exit 1; }
    require_key "$2"
    jq --arg k "$2" '.strings[$k]' "$FILE"
    ;;

  # Show or set the translator comment for a key
  comment)
    [ -z "${2:-}" ] && { echo "Usage: $0 comment <key> [text]" >&2; exit 1; }
    require_key "$2"
    if [ -n "${3:-}" ]; then
      apply_jq --arg k "$2" --arg c "$3" \
        '.strings[$k].comment = $c | del(.strings[$k].isCommentAutoGenerated)'
      echo "Set comment for \"$2\""
    else
      jq -r --arg k "$2" '.strings[$k].comment // "(no comment)"' "$FILE"
    fi
    ;;

  # Set a translation: ./l10n.sh set <key> <lang> <value>
  set)
    [ $# -lt 4 ] && { echo "Usage: $0 set <key> <lang> <value>" >&2; exit 1; }
    KEY="$2"; LOC="$3"; VALUE="$4"
    SRC=$(jq -r '.sourceLanguage // "en"' "$FILE")
    if ! key_exists "$KEY"; then
      if [ "$LOC" != "$SRC" ]; then
        echo "note: creating new key \"$KEY\" — also set its source-language ($SRC) value" >&2
      fi
    elif [ "$(jq -r --arg k "$KEY" --arg l "$LOC" \
        '.strings[$k].localizations[$l].variations != null' "$FILE")" = "true" ]; then
      echo "error: \"$KEY\" ($LOC) uses variations (plural/device); use set-plural or edit the JSON" >&2
      exit 1
    fi
    apply_jq --arg k "$KEY" --arg l "$LOC" --arg v "$VALUE" \
      '.strings[$k].localizations[$l].stringUnit = {"state": "translated", "value": $v}'
    echo "Set ${LOC} translation for \"${KEY}\""
    ;;

  # Set a plural variant: ./l10n.sh set-plural <key> <lang> <category> <value>
  set-plural)
    [ $# -lt 5 ] && { echo "Usage: $0 set-plural <key> <lang> <zero|one|two|few|many|other> <value>" >&2; exit 1; }
    KEY="$2"; LOC="$3"; CAT="$4"; VALUE="$5"
    case "$CAT" in zero|one|two|few|many|other) ;; *)
      echo "error: invalid plural category '$CAT' (zero|one|two|few|many|other)" >&2; exit 1 ;;
    esac
    apply_jq --arg k "$KEY" --arg l "$LOC" --arg c "$CAT" --arg v "$VALUE" '
      .strings[$k].localizations[$l] |= ((. // {}) | del(.stringUnit))
      | .strings[$k].localizations[$l].variations.plural[$c].stringUnit
          = {"state": "translated", "value": $v}'
    echo "Set ${LOC} plural (${CAT}) for \"${KEY}\""
    ;;

  # Batch set translations from a TSV file (key\tlang\tvalue), one jq pass.
  # \n and \t escapes in values become real newlines/tabs.
  batch-set)
    [ -z "${2:-}" ] && { echo "Usage: $0 batch-set <file.tsv>"; echo "TSV format: key<tab>lang<tab>value"; exit 1; }
    [ -f "$2" ] || { echo "error: file not found: $2" >&2; exit 1; }
    VALID=$(awk -F'\t' 'NF>=3{n++} END{print n+0}' "$2")
    BAD=$(awk -F'\t' 'NF>0 && NF<3{n++} END{print n+0}' "$2")
    [ "$BAD" -gt 0 ] && echo "warning: skipping $BAD malformed row(s) (need key<TAB>lang<TAB>value)" >&2
    [ "$VALID" -eq 0 ] && { echo "error: no valid rows in $2" >&2; exit 1; }
    apply_jq --rawfile tsv "$2" '
      def rows: $tsv | split("\n") | map(select(length > 0) | split("\t") | select(length >= 3));
      . as $cat
      | (rows | map(select($cat.strings[.[0]].localizations[.[1]].variations != null)
                    | "\(.[0]) [\(.[1])]")) as $conflicts
      | if ($conflicts | length) > 0
        then error("these keys use variations; use set-plural instead: " + ($conflicts | join(", ")))
        else . end
      | reduce rows[] as $r (.;
          .strings[$r[0]].localizations[$r[1]].stringUnit =
            {"state": "translated",
             "value": ($r[2:] | join("\t") | gsub("\\\\n"; "\n") | gsub("\\\\t"; "\t"))})'
    echo "Applied $VALID translation(s) from $2"
    ;;

  # List keys missing a usable translation for a language: no entry at all, or
  # any unit still in a non-"translated" state (new, needs_review, stale, …).
  # For the source language a missing entry is fine — the key is the value.
  missing)
    [ -z "${2:-}" ] && { echo "Usage: $0 missing <lang>" >&2; exit 1; }
    jq -r --arg l "$2" '
      .sourceLanguage as $src
      | .strings | to_entries[]
      | select(.value.shouldTranslate != false)
      | select(
          [.value.localizations[$l] | .. | objects | select(has("stringUnit")) | .stringUnit.state] as $states
          | if ($states | length) == 0 then $l != $src
            else $states | any(. != "translated") end
        )
      | .key
    ' "$FILE" | sort
    ;;

  # Show stats: fully translated count per language, plus pending/stale counts
  stats)
    jq -r --arg lf "${2:-}" '
      .sourceLanguage as $src
      | (.strings | to_entries | map(select(.value.shouldTranslate != false))) as $keys
      | ($keys | length) as $total
      | (.strings | to_entries | map(select(.value.extractionState == "stale")) | length) as $stale
      | (if $lf != "" then [$lf]
         else ($keys | map(.value.localizations // {} | keys) | flatten | unique) end) as $langs
      | "Source: \($src)",
        ("Translatable keys: \($total)" + (if $stale > 0 then " (\($stale) stale)" else "" end)),
        if ($langs | length) == 0 then "  No translations found"
        else
          ($langs[] as $l |
            ($keys | map([.value.localizations[$l] | .. | objects
                          | select(has("stringUnit")) | .stringUnit.state])) as $states |
            ($states | map(select(
              if length == 0 then $l == $src else all(. == "translated") end
            )) | length) as $done |
            ($states | map(select(length > 0 and any(. != "translated"))) | length) as $pending |
            "  \($l): \($done)/\($total)"
              + (if $pending > 0 then " (\($pending) pending review)" else "" end)
          )
        end
    ' "$FILE"
    ;;

  # List keys Xcode marked stale (no longer found in code during extraction)
  stale)
    OUT=$(jq -r '.strings | to_entries[] | select(.value.extractionState == "stale") | .key' "$FILE" | sort)
    [ -n "$OUT" ] && printf '%s\n' "$OUT" || echo "No stale keys."
    ;;

  # Rename a key: ./l10n.sh rename <old-key> <new-key>
  rename)
    [ -z "${3:-}" ] && { echo "Usage: $0 rename <old-key> <new-key>" >&2; exit 1; }
    OLD="$2"; NEW="$3"
    apply_jq --arg old "$OLD" --arg new "$NEW" '
      if (.strings | has($old)) | not then error("Key not found: \($old)")
      elif .strings | has($new) then error("Target key already exists: \($new)")
      else .strings[$new] = .strings[$old] | del(.strings[$old])
      end'
    echo "Renamed \"${OLD}\" → \"${NEW}\""
    echo "note: update source-code references too, or the next Xcode build re-adds the old key" >&2
    ;;

  # Delete a key or a single translation: ./l10n.sh delete <key> [lang]
  delete)
    [ -z "${2:-}" ] && { echo "Usage: $0 delete <key> [lang]" >&2; exit 1; }
    KEY="$2"; LOC="${3:-}"
    require_key "$KEY"
    if [ -z "$LOC" ]; then
      apply_jq --arg k "$KEY" 'del(.strings[$k])'
      echo "Deleted key \"${KEY}\""
    else
      apply_jq --arg k "$KEY" --arg l "$LOC" 'del(.strings[$k].localizations[$l])'
      echo "Deleted ${LOC} translation for \"${KEY}\""
    fi
    ;;

  # Re-normalize the file to Xcode's exact .xcstrings format. Run after Xcode or
  # any other tool (or an older version of this script) has reformatted it.
  normalize)
    normalize_xcstrings "$FILE"
    echo "Normalized $FILE to Xcode .xcstrings format"
    ;;

  *)
    echo "l10n.sh — Xcode String Catalog (.xcstrings) helper"
    echo ""
    echo "Catalog: $FILE"
    echo "(override with L10N_FILE=<path>)"
    echo ""
    echo "Commands:"
    echo "  file                                   Print the resolved catalog path"
    echo "  keys                                   List all translatable keys"
    echo "  search <pattern>                       Search keys (case-insensitive)"
    echo "  search-values <pattern>                Search translation values"
    echo "  get <key>                              Show translations for a key"
    echo "  comment <key> [text]                   Show or set the translator comment"
    echo "  set <key> <lang> <value>               Set a translation"
    echo "  set-plural <key> <lang> <cat> <value>  Set a plural variant (zero|one|two|few|many|other)"
    echo "  batch-set <file.tsv>                   Batch set from TSV (key\\tlang\\tvalue)"
    echo "  missing <lang>                         Keys missing or pending translation for <lang>"
    echo "  stats [lang]                           Translation stats per language"
    echo "  stale                                  Keys Xcode marked stale (removed from code)"
    echo "  rename <old-key> <new-key>             Rename a key, preserving translations"
    echo "  delete <key> [lang]                    Delete a key or a single translation"
    echo "  normalize                              Re-serialize to Xcode's exact format"
    ;;
esac
