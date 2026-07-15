#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

xcodegen -s project.yml
xcrun swift-format lint --strict --recursive App Packages Tests
Scripts/validate-assets.sh
swift test --package-path Packages/PimPoPomCore
xcodebuild \
  -project PimPoPom.xcodeproj \
  -scheme PimPoPom \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build

if ! xcrun simctl list devices available | rg -Fq 'PimPoPom iPhone SE 2022 ('; then
  printf '%s\n' 'Missing PimPoPom iPhone SE 2022 simulator. Run Scripts/create-alpha-simulators.sh first.' >&2
  exit 1
fi

xcodebuild -quiet \
  -project PimPoPom.xcodeproj \
  -scheme PimPoPom \
  -destination 'platform=iOS Simulator,name=PimPoPom iPhone SE 2022' \
  test
git diff --check
