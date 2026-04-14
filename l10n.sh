#!/bin/bash
# l10n.sh — Helper for reading/editing Localizable.xcstrings
# Usage: ./l10n.sh <command> [args]

FILE="swmpc/Localizable.xcstrings"

case "${1}" in

  # List all translatable keys (one per line)
  keys)
    jq -r '.strings | to_entries[] | select(.value.shouldTranslate != false) | .key' "$FILE" | sort
    ;;

  # Search keys matching a pattern (case-insensitive grep)
  search)
    [ -z "$2" ] && { echo "Usage: $0 search <pattern>"; exit 1; }
    jq -r '.strings | to_entries[] | select(.value.shouldTranslate != false) | .key' "$FILE" | sort | grep -i "$2"
    ;;

  # Get translations for a specific key (all languages)
  get)
    [ -z "$2" ] && { echo "Usage: $0 get <key>"; exit 1; }
    jq --arg k "$2" '.strings[$k]' "$FILE"
    ;;

  # Set a translation: ./l10n.sh set <key> <lang> <value>
  set)
    [ -z "$4" ] && { echo "Usage: $0 set <key> <lang> <value>"; exit 1; }
    KEY="$2"; LANG="$3"; VALUE="$4"
    jq --arg k "$KEY" --arg l "$LANG" --arg v "$VALUE" \
      '.strings[$k].localizations[$l].stringUnit = {"state": "translated", "value": $v}' \
      "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
    echo "Set ${LANG} translation for \"${KEY}\""
    ;;

  # Batch set translations from stdin (TSV: key\tlang\tvalue)
  batch-set)
    [ -z "$2" ] && { echo "Usage: $0 batch-set <file.tsv>"; echo "TSV format: key<tab>lang<tab>value"; exit 1; }
    TMPFILE="${FILE}"
    while IFS=$'\t' read -r KEY LANG VALUE; do
      [ -z "$VALUE" ] && continue
      jq --arg k "$KEY" --arg l "$LANG" --arg v "$VALUE" \
        '.strings[$k].localizations[$l].stringUnit = {"state": "translated", "value": $v}' \
        "$TMPFILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$TMPFILE"
      echo "Set ${LANG}: \"${KEY}\""
    done < "$2"
    ;;

  # List keys missing a translation for a given language
  missing)
    [ -z "$2" ] && { echo "Usage: $0 missing <lang>"; exit 1; }
    jq -r --arg l "$2" '
      .strings | to_entries[]
      | select(.value.shouldTranslate != false)
      | select(.value.localizations[$l] == null)
      | .key
    ' "$FILE" | sort
    ;;

  # Show stats: count of keys, translated, untranslated per language
  stats)
    LANGS="${2:-}"
    if [ -n "$LANGS" ]; then
      LANG_FILTER="[\"$LANGS\"]"
    else
      LANG_FILTER="null"
    fi
    jq -r --argjson lf "$LANG_FILTER" '
      .sourceLanguage as $src |
      (.strings | to_entries | map(select(.value.shouldTranslate != false))) as $keys |
      ($keys | length) as $total |
      (if $lf then $lf else ($keys | map(.value.localizations // {} | keys) | flatten | unique) end) as $langs |
      "Source: \($src)",
      "Translatable keys: \($total)",
      if ($langs | length) == 0 then "  No translations found"
      else
        ($langs[] as $l |
          ($keys | map(select(.value.localizations[$l] != null)) | length) as $done |
          "  \($l): \($done)/\($total)"
        )
      end
    ' "$FILE"
    ;;

  # Rename a key: ./l10n.sh rename <old-key> <new-key>
  rename)
    [ -z "$3" ] && { echo "Usage: $0 rename <old-key> <new-key>"; exit 1; }
    OLD="$2"; NEW="$3"
    jq --arg old "$OLD" --arg new "$NEW" '
      if .strings[$old] then
        .strings[$new] = .strings[$old] | del(.strings[$old])
      else
        error("Key not found: \($old)")
      end
    ' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
    echo "Renamed \"${OLD}\" → \"${NEW}\""
    ;;

  # Delete a key or a single translation: ./l10n.sh delete <key> [lang]
  delete)
    [ -z "$2" ] && { echo "Usage: $0 delete <key> [lang]"; exit 1; }
    KEY="$2"; LANG="$3"
    if [ -z "$LANG" ]; then
      jq --arg k "$KEY" 'del(.strings[$k])' \
        "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
      echo "Deleted key \"${KEY}\""
    else
      jq --arg k "$KEY" --arg l "$LANG" \
        'del(.strings[$k].localizations[$l])' \
        "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
      echo "Deleted ${LANG} translation for \"${KEY}\""
    fi
    ;;

  *)
    echo "l10n.sh — Localizable.xcstrings helper"
    echo ""
    echo "Commands:"
    echo "  keys                         List all translatable keys"
    echo "  search <pattern>             Search keys (case-insensitive)"
    echo "  get <key>                    Show translations for a key"
    echo "  set <key> <lang> <value>     Set a translation"
    echo "  batch-set <file.tsv>         Batch set from TSV (key\\tlang\\tvalue)"
    echo "  missing <lang>               List keys missing translation for <lang>"
    echo "  stats                        Show translation stats"
    echo "  rename <old-key> <new-key>   Rename a key, preserving translations"
    echo "  delete <key> [lang]          Delete a key or a single translation"
    ;;
esac
