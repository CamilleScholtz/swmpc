#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: xcode.sh <command> [options]

Commands:
  status            Show active Xcode workspace document and active scheme
  schemes           List available schemes in the active workspace
  scheme [name]     Get or set the active scheme (e.g. "swmpc", "widget")
  build [scheme]    Build active (or specified) scheme in Xcode, wait for completion
  clean             Clean active workspace document in Xcode
  test [scheme]     Run tests for active (or specified) scheme in Xcode
  run               Run active scheme in Xcode
  logs [--errors]   Print build log from the last scheme action (or only errors)

Examples:
  xcode.sh status
  xcode.sh build widget
  xcode.sh logs --errors
EOF
}

check_xcode() {
    if ! pgrep -x "Xcode" >/dev/null 2>&1 && ! pgrep -f "Xcode.*MacOS/Xcode" >/dev/null 2>&1; then
        echo "Error: Xcode is not currently running." >&2
        exit 1
    fi
}

cmd="${1:-}"
shift || true

case "$cmd" in
    status)
        check_xcode
        osascript <<'EOF'
tell application "Xcode"
    if not (exists active workspace document) then
        error "No workspace document is currently open in Xcode."
    end if
    set doc to active workspace document
    set docName to name of doc
    set sName to name of active scheme of doc
    set isLoaded to loaded of doc
    return "Workspace: " & docName & " (loaded: " & isLoaded & ")" & linefeed & "Active Scheme: " & sName
end tell
EOF
        ;;

    schemes)
        check_xcode
        osascript <<'EOF'
tell application "Xcode"
    set doc to active workspace document
    set sList to name of schemes of doc
    set AppleScript's text item delimiters to linefeed
    return sList as text
end tell
EOF
        ;;

    scheme)
        check_xcode
        target="${1:-}"
        if [ -z "$target" ]; then
            osascript -e 'tell application "Xcode" to return name of active scheme of active workspace document'
        else
            osascript -e '
            on run argv
                set targetScheme to item 1 of argv
                tell application "Xcode"
                    set doc to active workspace document
                    set availableSchemes to name of schemes of doc
                    if availableSchemes does not contain targetScheme then
                        error "Scheme \"" & targetScheme & "\" not found in workspace."
                    end if
                    set active scheme of doc to scheme targetScheme of doc
                    return "Active scheme set to: " & targetScheme
                end tell
            end run' "$target"
        fi
        ;;

    build)
        check_xcode
        target="${1:-}"
        if [ -n "$target" ]; then
            "$0" scheme "$target" >/dev/null
        fi

        echo "Building in Xcode..."
        result=$(osascript <<'EOF'
tell application "Xcode"
    set doc to active workspace document
    set sName to name of active scheme of doc
    set res to build doc
    repeat while not (completed of res)
        delay 0.5
    end repeat
    set resStatus to status of res as text
    set resError to error message of res as text
    return sName & "|" & resStatus & "|" & resError
end tell
EOF
)
        scheme_name=$(echo "$result" | cut -d'|' -f1)
        status=$(echo "$result" | cut -d'|' -f2)
        error_msg=$(echo "$result" | cut -d'|' -f3)

        if [ "$status" = "succeeded" ]; then
            echo "Build succeeded ($scheme_name)"
            exit 0
        else
            echo "Build $status ($scheme_name)" >&2
            if [ "$error_msg" != "missing value" ] && [ -n "$error_msg" ]; then
                echo "Error: $error_msg" >&2
            fi
            echo "" >&2
            echo "--- Errors from build log ---" >&2
            "$0" logs --errors >&2
            exit 1
        fi
        ;;

    clean)
        check_xcode
        echo "Cleaning workspace in Xcode..."
        result=$(osascript <<'EOF'
tell application "Xcode"
    set doc to active workspace document
    set res to clean doc
    repeat while not (completed of res)
        delay 0.5
    end repeat
    return status of res as text
end tell
EOF
)
        echo "Clean $result"
        ;;

    test)
        check_xcode
        target="${1:-}"
        if [ -n "$target" ]; then
            "$0" scheme "$target" >/dev/null
        fi

        echo "Testing in Xcode..."
        result=$(osascript <<'EOF'
tell application "Xcode"
    set doc to active workspace document
    set sName to name of active scheme of doc
    set res to test doc
    repeat while not (completed of res)
        delay 0.5
    end repeat
    set resStatus to status of res as text
    set resError to error message of res as text
    return sName & "|" & resStatus & "|" & resError
end tell
EOF
)
        scheme_name=$(echo "$result" | cut -d'|' -f1)
        status=$(echo "$result" | cut -d'|' -f2)
        error_msg=$(echo "$result" | cut -d'|' -f3)

        if [ "$status" = "succeeded" ]; then
            echo "Tests succeeded ($scheme_name)"
            exit 0
        else
            echo "Tests $status ($scheme_name)" >&2
            if [ "$error_msg" != "missing value" ] && [ -n "$error_msg" ]; then
                echo "Error: $error_msg" >&2
            fi
            exit 1
        fi
        ;;

    run)
        check_xcode
        echo "Running active scheme in Xcode..."
        osascript -e 'tell application "Xcode" to run active workspace document'
        echo "Run action initiated in Xcode."
        ;;

    logs)
        check_xcode
        opt="${1:-}"
        log_content=$(osascript <<'EOF'
tell application "Xcode"
    set doc to active workspace document
    set res to last scheme action result of doc
    if res is missing value then
        return "No scheme action result available."
    end if
    return build log of res
end tell
EOF
)
        if [ "$opt" = "--errors" ]; then
            echo "$log_content" | grep -E -i "error:|failed|fatal" || echo "No explicit error lines found in log."
        else
            echo "$log_content"
        fi
        ;;

    -h|--help|help|"")
        usage
        exit 0
        ;;

    *)
        echo "Unknown command: $cmd" >&2
        usage >&2
        exit 1
        ;;
esac
