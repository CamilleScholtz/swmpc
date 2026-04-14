#!/bin/bash
# Find unused translation keys in swmpc project
# Handles format specifiers, special characters, and interpolation patterns.

cd /Users/camille/Developer/Home/swmpc

# Combine all Swift source files into one temp file for searching
COMBINED=$(mktemp)
find swmpc -name '*.swift' -type f -exec cat {} + > "$COMBINED"

# Get all keys
KEYS_FILE=$(mktemp)
./l10n.sh keys > "$KEYS_FILE" 2>/dev/null

unused_keys=()

while IFS= read -r key; do
    [ -z "$key" ] && continue

    # 1. Try exact literal match first (handles most keys)
    if grep -qF "$key" "$COMBINED" 2>/dev/null; then
        continue
    fi

    # 2. For keys with format specifiers, the key in code uses Swift interpolation
    has_specifier=false
    if echo "$key" | grep -qE '%(@|lld|lf|d|f|s|%%|\d+\$@|\d+\$lld)|\^\['; then
        has_specifier=true
    fi

    if $has_specifier; then
        # Replace format specifiers with newlines to get static segments
        cleaned=$(echo "$key" | sed -E 's/%[0-9]*\$?(@|lld|lf|d|f|s)|%%/\n/g' | sed -E 's/\^\[//g')

        # Collect ALL non-empty static segments
        meaningful_segments=()
        while IFS= read -r segment; do
            trimmed=$(echo "$segment" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            if [ ${#trimmed} -ge 1 ]; then
                meaningful_segments+=("$trimmed")
            fi
        done < <(echo "$cleaned")

        # If we have meaningful segments, check if ALL appear in source
        # For segments with non-ASCII chars (like ≈), also try Unicode escape forms
        if [ ${#meaningful_segments[@]} -gt 0 ]; then
            all_found=true
            for seg in "${meaningful_segments[@]}"; do
                if ! grep -qF "$seg" "$COMBINED" 2>/dev/null; then
                    # Try checking for Unicode escapes of non-ASCII chars
                    # Convert non-ASCII chars to \u{XXXX} pattern and search
                    has_non_ascii=$(echo "$seg" | LC_ALL=C grep -c '[^\x00-\x7F]')
                    if [ "$has_non_ascii" -gt 0 ]; then
                        # Non-ASCII char present; likely used via \u{...} escape in source
                        # Check if ASCII parts of the segment are present
                        ascii_part=$(echo "$seg" | LC_ALL=C sed 's/[^\x00-\x7F]//g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                        if [ ${#ascii_part} -ge 1 ] && grep -qF "$ascii_part" "$COMBINED" 2>/dev/null; then
                            continue  # This segment found via ASCII fallback
                        fi
                    fi
                    all_found=false
                    break
                fi
            done
            if $all_found; then
                continue
            fi
        fi

        # Fallback: check if the key is purely format specifiers (like "%lld%%")
        # These appear in code as "\(value)%" - check for )% pattern
        only_specifiers=$(echo "$key" | sed -E 's/%[0-9]*\$?(@|lld|lf|d|f|s)|%%//g' | sed 's/[[:space:]]//g')
        if [ -z "$only_specifiers" ]; then
            # Key is purely format specifiers like "%lld%%"
            # The %% becomes literal % in output - check for )%" pattern
            if grep -q ')%"' "$COMBINED" 2>/dev/null; then
                continue
            fi
        fi

        # Fallback: try prefix before first specifier (>= 3 chars)
        prefix=$(echo "$key" | sed -E 's/(%[0-9]*\$?(@|lld|lf|d|f|s)|%%|\^\[).*//')
        if [ ${#prefix} -ge 3 ]; then
            if grep -qF "$prefix" "$COMBINED" 2>/dev/null; then
                continue
            fi
        fi

        # Fallback: try suffix after last specifier (>= 3 chars)
        suffix=$(echo "$key" | sed -E 's/.*(%[0-9]*\$?(@|lld|lf|d|f|s)|%%|\])//')
        suffix_trimmed=$(echo "$suffix" | sed 's/^[[:space:]]*//')
        if [ ${#suffix_trimmed} -ge 3 ]; then
            if grep -qF "$suffix_trimmed" "$COMBINED" 2>/dev/null; then
                continue
            fi
        fi
    fi

    # 3. Key not found
    unused_keys+=("$key")

done < "$KEYS_FILE"

echo "=== UNUSED TRANSLATION KEYS ==="
echo "Total unused: ${#unused_keys[@]}"
echo ""
for k in "${unused_keys[@]}"; do
    echo "$k"
done

rm -f "$COMBINED" "$KEYS_FILE"
