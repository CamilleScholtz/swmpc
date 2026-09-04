#!/usr/bin/env python3
"""Filter GetTargetBuildSettings JSON to security-relevant entries.

Usage:
    filter_build_settings.py <saved-file> [--show-overrides] [--unhardened-only] [--regex REGEX]
"""

import argparse
import json
import re
from pathlib import Path

REFERENCE_PATH = (
    Path(__file__).resolve().parent.parent
    / "references"
    / "security-settings-reference.md"
)

# Settings the script needs that aren't documented in the security reference
# as security settings but are required to interpret results (entitlements
# path, SDK, supported platforms).
EXTRA_NAMES = ("CODE_SIGN_ENTITLEMENTS", "SDKROOT", "SUPPORTED_PLATFORMS")

# Tokens inside backticks that look like build-setting macro names.
_NAME_RX = re.compile(r"`([A-Z][A-Z0-9_]{2,})`")

HARDENED_VALUES = {"YES", "YES_AGGRESSIVE", "YES_ERROR"}


def _load_reference_names(path: Path) -> list[str]:
    text = path.read_text()
    names = {
        n
        for n in _NAME_RX.findall(text)
        if n not in HARDENED_VALUES and n not in {"NO", "TRUE", "FALSE"}
    }
    names.update(EXTRA_NAMES)
    # Longest-first so prefix-like names don't get shadowed in alternation.
    return sorted(names, key=lambda n: (-len(n), n))


def _default_regex() -> str:
    return "^(" + "|".join(re.escape(n) for n in _load_reference_names(REFERENCE_PATH)) + ")$"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("saved_file", nargs="?", default="-",
                        help="Path to build settings JSON (or '-' for stdin)")
    parser.add_argument("--regex", default=None,
                        help="Override the reference-derived default regex")
    parser.add_argument("--show-overrides", action="store_true",
                        help="Annotate target-level overrides with [target-override]")
    parser.add_argument("--unhardened-only", action="store_true",
                        help="Only show settings whose evaluatedValue is not YES/YES_AGGRESSIVE/YES_ERROR")
    args = parser.parse_args()

    pattern = args.regex if args.regex else _default_regex()
    rx = re.compile(pattern)

    import sys
    if args.saved_file == "-" or not args.saved_file:
        data = json.load(sys.stdin)
    else:
        with open(args.saved_file) as f:
            data = json.load(f)

    # Normalize various schemas (Xcode MCP GetTargetBuildSettings, xcodebuild -showBuildSettings -json, dict)
    settings_list = []
    if isinstance(data, list):
        for entry in data:
            bs = entry.get("buildSettings", entry)
            if isinstance(bs, dict):
                for k, v in bs.items():
                    settings_list.append({"name": k, "val": str(v), "override": False})
            elif isinstance(bs, list):
                for item in bs:
                    settings_list.append({
                        "name": item.get("macroName", ""),
                        "val": str(item.get("evaluatedValue", "")),
                        "override": "targetValue" in item
                    })
    elif isinstance(data, dict):
        bs = data.get("buildSettings", data)
        if isinstance(bs, list):
            for item in bs:
                settings_list.append({
                    "name": item.get("macroName", ""),
                    "val": str(item.get("evaluatedValue", "")),
                    "override": "targetValue" in item
                })
        elif isinstance(bs, dict):
            for k, v in bs.items():
                settings_list.append({"name": k, "val": str(v), "override": False})

    for s in settings_list:
        name = s["name"]
        val = s.get("val", "")
        if not rx.search(name):
            continue
        if args.unhardened_only and val in HARDENED_VALUES:
            continue
        flag = "  [target-override]" if args.show_overrides and s.get("override") else ""
        print(f"{name}={val}{flag}")


if __name__ == "__main__":
    main()
