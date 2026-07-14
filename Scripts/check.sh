#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

xcodegen -s project.yml
swift test --package-path Packages/PimPoPomCore
xcodebuild \
  -project PimPoPom.xcodeproj \
  -scheme PimPoPom \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
git diff --check
