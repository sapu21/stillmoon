#!/bin/bash
# Regenerates the Xcode project and runs tests on the iPhone 17 Pro simulator.
# Extra arguments go to xcodebuild, e.g. -only-testing:StillmoonTests/LocalStoreTests
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate --quiet
set +e
xcodebuild test -project Stillmoon.xcodeproj -scheme Stillmoon \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' "$@" 2>&1 \
  | tee /tmp/stillmoon-test.log \
  | grep -E 'error:|✘|✔ Test run|Test Suite .*(passed|failed)|Executed [0-9]+ test|\*\* TEST (SUCCEEDED|FAILED) \*\*'
status=${PIPESTATUS[0]}
exit $status
