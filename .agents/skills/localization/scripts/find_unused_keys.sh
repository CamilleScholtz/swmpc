#!/bin/bash
# Find catalog keys that are not referenced anywhere in the project sources.
# Handles format specifiers (%@, %lld, …), Swift string-escape forms, and
# interpolation patterns. Purely textual — it cannot see dynamically built
# keys, so verify each hit before deleting.
#
# Lives at .claude/skills/localization/scripts/find_unused_keys.sh. The project
# root is resolved from this script's own location so it works from any
# directory; the catalog comes from `l10n.sh file` (override with $L10N_FILE).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
FILE="$("$SCRIPT_DIR/l10n.sh" file)"

command -v python3 >/dev/null 2>&1 || { echo "error: python3 is required" >&2; exit 1; }

python3 - "$FILE" "$PROJECT_ROOT" <<'PY'
import json
import os
import re
import sys

catalog_path, root = sys.argv[1], sys.argv[2]

with open(catalog_path, encoding="utf-8") as f:
    catalog = json.load(f)

keys = [k for k, v in catalog["strings"].items()
        if v.get("shouldTranslate") is not False]
stale = {k for k, v in catalog["strings"].items()
         if v.get("extractionState") == "stale"}

# Directories that never contain app source referencing catalog keys.
PRUNE = {".build", "DerivedData", "Pods", "Carthage", "node_modules"}
EXTS = (".swift", ".m", ".mm", ".h", ".storyboard", ".xib", ".intentdefinition")

chunks = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames
                   if d not in PRUNE and not d.startswith(".")]
    for name in filenames:
        if name.endswith(EXTS):
            try:
                with open(os.path.join(dirpath, name),
                          encoding="utf-8", errors="ignore") as fh:
                    chunks.append(fh.read())
            except OSError:
                pass
source = "\n".join(chunks)

def swift_escaped(s):
    """The form a key takes inside a Swift string literal."""
    return (s.replace("\\", "\\\\").replace('"', '\\"')
             .replace("\n", "\\n").replace("\t", "\\t"))

def found(fragment):
    return fragment in source or swift_escaped(fragment) in source

# Placeholders: in code these keys use Swift interpolation ("\(count)"), so
# only the static segments between placeholders can be matched. Covers printf
# format specifiers and App Intents parameter placeholders ("${mode}", written
# in code as "\(\.$mode)").
SPEC = re.compile(r"%(?:\d+\$)?(?:@|lld|llu|ld|lu|d|u|lf|f|e|g|s|c|\.\d+f)|%%|\$\{[^}]*\}")

unused, unverifiable = [], []
for key in keys:
    if found(key):
        continue
    if not SPEC.search(key):
        unused.append(key)
        continue
    segments = [seg.strip() for seg in SPEC.split(key)]
    segments = [seg for seg in segments if seg]
    if not segments:
        # Placeholder-only key like "%lld%%" — nothing textual to match.
        unverifiable.append(key)
        continue
    if all(found(seg) for seg in segments):
        continue
    # A single long segment matching is strong evidence the key is used but
    # assembled with different interpolation around it.
    if any(len(seg) >= 3 and found(seg) for seg in segments):
        continue
    unused.append(key)

def annotate(k):
    return f"{k}\t[also marked stale by Xcode]" if k in stale else k

print(f"Checked {len(keys)} translatable keys against sources under {root}")
print()
if unused:
    print(f"=== LIKELY UNUSED ({len(unused)}) ===")
    for k in sorted(unused):
        print(annotate(k))
else:
    print("No unused keys found.")
if unverifiable:
    print()
    print(f"=== UNVERIFIABLE — placeholder-only keys ({len(unverifiable)}) ===")
    for k in sorted(unverifiable):
        print(k)
print()
print("Note: matching is textual; dynamically built keys "
      "(e.g. String(localized: someVariable)) are invisible to it.")
print("Verify each key before removing it with: l10n.sh delete <key>")
PY
