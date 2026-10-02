#!/usr/bin/env bash
# FamilyFood test runner — the one command to verify a change. CI runs exactly this script.
#
#   scripts/test.sh                    # regenerate the Xcode project + run all tests
#   scripts/test.sh -only-testing:FamilyFoodTests/SuggestionEngineTests   # extra xcodebuild args pass through
#   FF_DESTINATION='platform=iOS Simulator,name=iPhone 17' scripts/test.sh   # pick the simulator yourself
#
# Without FF_DESTINATION the first available iPhone simulator is used.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null; then
    echo "error: xcodegen not found — install it first: https://github.com/yonaskolb/XcodeGen#installing" >&2
    exit 1
fi

if [ -z "${FF_DESTINATION:-}" ]; then
    devices=$(xcrun simctl list devices available)
    # Lines look like "    iPhone 16 (0FEDE226-…) (Shutdown)" — take the first iPhone's identifier.
    device_id=$(awk -F'[()]' '/^ +iPhone /{print $2; exit}' <<<"$devices")
    if [ -z "$device_id" ]; then
        echo "error: no iPhone simulator available — add one in Xcode (Settings ▸ Components), or set FF_DESTINATION" >&2
        exit 1
    fi
    FF_DESTINATION="platform=iOS Simulator,id=$device_id"
fi

xcodegen generate
# -collect-test-diagnostics never: after a failing run xcodebuild otherwise waits up to ten
# minutes for simulator diagnostics before it reports the result.
xcodebuild test -project FamilyFood.xcodeproj -scheme FamilyFood -destination "$FF_DESTINATION" \
    -collect-test-diagnostics never "$@"
