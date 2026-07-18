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

build_settings=$(xcodebuild \
  -project PimPoPom.xcodeproj \
  -scheme PimPoPom \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -showBuildSettings)
target_build_dir=$(printf '%s\n' "$build_settings" | awk -F ' = ' '/ TARGET_BUILD_DIR = / { print $2; exit }')
wrapper_name=$(printf '%s\n' "$build_settings" | awk -F ' = ' '/ WRAPPER_NAME = / { print $2; exit }')
built_info_plist="$target_build_dir/$wrapper_name/Info.plist"
bundle_identifier=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$built_info_plist")
test "$bundle_identifier" = "com.otcsoftware.pimpopom"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$built_info_plist")" = "PimPoPom"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$built_info_plist")" = "PimPoPom"
test "$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "$built_info_plist")" = "false"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName' "$built_info_plist")" = "AppIcon"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundleAlternateIcons:AppIconLight:CFBundleIconName' "$built_info_plist")" = "AppIconLight"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundleAlternateIcons:AppIconPixel:CFBundleIconName' "$built_info_plist")" = "AppIconPixel"
test "$(/usr/libexec/PlistBuddy -c 'Print :UIApplicationShortcutItems:0:UIApplicationShortcutItemTitle' "$built_info_plist")" = "Change Icon"
test "$(/usr/libexec/PlistBuddy -c 'Print :UIApplicationShortcutItems:0:UIApplicationShortcutItemIconType' "$built_info_plist")" = "UIApplicationShortcutIconTypeUpdate"
test "$(/usr/libexec/PlistBuddy -c 'Print :UIApplicationShortcutItems:0:UIApplicationShortcutItemType' "$built_info_plist")" = "$bundle_identifier.change-icon"
test "$(/usr/libexec/PlistBuddy -c 'Print :UIApplicationShortcutItems:0:UIApplicationShortcutItemUserInfo:url' "$built_info_plist")" = "pimpopom://settings/icon"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:1:CFBundleURLSchemes:0' "$built_info_plist")" = "pimpopom"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.game-center' Config/PimPoPom.entitlements)" = "true"

staging_build_settings=$(xcodebuild \
  -project PimPoPom.xcodeproj \
  -scheme 'PimPoPom Staging' \
  -configuration Staging \
  -destination 'generic/platform=iOS' \
  -showBuildSettings)
printf '%s\n' "$staging_build_settings" | rg -Fq 'CONFIGURATION = Staging'
printf '%s\n' "$staging_build_settings" | rg -Fq 'PRODUCT_BUNDLE_IDENTIFIER = com.otcsoftware.pimpopom'
printf '%s\n' "$staging_build_settings" | rg -Fq 'MARKETING_VERSION = 1.0'
printf '%s\n' "$staging_build_settings" | rg -Fq 'CURRENT_PROJECT_VERSION = 1'
printf '%s\n' "$staging_build_settings" | rg -Fq 'CODE_SIGN_ENTITLEMENTS = Config/PimPoPom.entitlements'

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
