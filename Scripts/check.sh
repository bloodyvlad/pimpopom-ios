#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

xcodegen -s project.yml
xcrun swift-format lint --strict --recursive App Packages Tests
Scripts/validate-assets.sh
Scripts/test-ad-configuration.sh
plutil -lint Config/Info.plist App/Resources/PrivacyInfo.xcprivacy
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
test "$(/usr/libexec/PlistBuddy -c 'Print :GADApplicationIdentifier' "$built_info_plist")" = "ca-app-pub-6428992187280935~3622035442"
test "$(/usr/libexec/PlistBuddy -c 'Print :PimPoPomAdsMode' "$built_info_plist")" = "demo"
test "$(/usr/libexec/PlistBuddy -c 'Print :PimPoPomAdMobBannerUnitID' "$built_info_plist")" = "ca-app-pub-3940256099942544/2934735716"
test "$(/usr/libexec/PlistBuddy -c 'Print :PimPoPomAdMobInterstitialUnitID' "$built_info_plist")" = "ca-app-pub-3940256099942544/4411468910"
ad_test_ids=$(/usr/libexec/PlistBuddy -c 'Print :PimPoPomAdMobTestDeviceIDs' "$built_info_plist" 2>/dev/null || true)
test -z "$ad_test_ids"
if /usr/libexec/PlistBuddy -c 'Print :NSUserTrackingUsageDescription' "$built_info_plist" >/dev/null 2>&1; then
  printf '%s\n' 'NSUserTrackingUsageDescription must not be present.' >&2
  exit 1
fi
skad_json=$(plutil -extract SKAdNetworkItems json -o - "$built_info_plist")
test "$(printf '%s\n' "$skad_json" | rg -o '[a-z0-9]+\.skadnetwork' | wc -l | tr -d ' ')" = "50"
test "$(printf '%s\n' "$skad_json" | rg -o '[a-z0-9]+\.skadnetwork' | sort -u | wc -l | tr -d ' ')" = "50"
test -f "$target_build_dir/$wrapper_name/PrivacyInfo.xcprivacy"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName' "$built_info_plist")" = "AppIcon"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundleAlternateIcons:AppIconLight:CFBundleIconName' "$built_info_plist")" = "AppIconLight"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons:CFBundleAlternateIcons:AppIconPixel:CFBundleIconName' "$built_info_plist")" = "AppIconPixel"
test "$(/usr/libexec/PlistBuddy -c 'Print :UIApplicationShortcutItems:0:UIApplicationShortcutItemTitle' "$built_info_plist")" = "Change Icon"
test "$(/usr/libexec/PlistBuddy -c 'Print :UIApplicationShortcutItems:0:UIApplicationShortcutItemIconType' "$built_info_plist")" = "UIApplicationShortcutIconTypeUpdate"
test "$(/usr/libexec/PlistBuddy -c 'Print :UIApplicationShortcutItems:0:UIApplicationShortcutItemType' "$built_info_plist")" = "$bundle_identifier.change-icon"
test "$(/usr/libexec/PlistBuddy -c 'Print :UIApplicationShortcutItems:0:UIApplicationShortcutItemUserInfo:url' "$built_info_plist")" = "pimpopom://settings/icon"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleURLTypes:1:CFBundleURLSchemes:0' "$built_info_plist")" = "pimpopom"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.game-center' Config/PimPoPom.entitlements)" = "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.developer.applesignin:0' Config/PimPoPom.entitlements)" = "Default"

staging_build_settings=$(xcodebuild \
  -project PimPoPom.xcodeproj \
  -scheme 'PimPoPom Staging' \
  -configuration Staging \
  -destination 'generic/platform=iOS' \
  -showBuildSettings)
printf '%s\n' "$staging_build_settings" | rg -Fq 'CONFIGURATION = Staging'
printf '%s\n' "$staging_build_settings" | rg -Fq 'PRODUCT_BUNDLE_IDENTIFIER = com.otcsoftware.pimpopom'
printf '%s\n' "$staging_build_settings" | rg -Fq 'MARKETING_VERSION = 1.2'
printf '%s\n' "$staging_build_settings" | rg -Fq 'CURRENT_PROJECT_VERSION = 15'
printf '%s\n' "$staging_build_settings" | rg -Fq 'CODE_SIGN_ENTITLEMENTS = Config/PimPoPom.entitlements'
printf '%s\n' "$staging_build_settings" | rg -Fq 'PIMPOPOM_ADMOB_BANNER_UNIT_ID = ca-app-pub-3940256099942544/2934735716'
printf '%s\n' "$staging_build_settings" | rg -Fq 'PIMPOPOM_ADMOB_INTERSTITIAL_UNIT_ID = ca-app-pub-3940256099942544/4411468910'
printf '%s\n' "$staging_build_settings" | rg -Fq 'PIMPOPOM_ADS_MODE = owner-split-test'
printf '%s\n' "$staging_build_settings" | rg -Fq 'PIMPOPOM_ADMOB_OWNER_BANNER_UNIT_ID = ca-app-pub-6428992187280935/3513535878'
printf '%s\n' "$staging_build_settings" | rg -Fq 'PIMPOPOM_ADMOB_OWNER_INTERSTITIAL_UNIT_ID = ca-app-pub-6428992187280935/5433122203'
printf '%s\n' "$staging_build_settings" | rg -Fq 'PIMPOPOM_ADMOB_TEST_DEVICE_IDS = 65889f215752fbc9ad39e52b00d92987'
printf '%s\n' "$staging_build_settings" | awk -F ' = ' '/ PIMPOPOM_OWNER_DEVICE_IDFV_SHA256S = / { print $2; exit }' | rg -q '^[[:xdigit:]]{64}(,[[:xdigit:]]{64}){0,3}$'

owner_ads_build_settings=$(xcodebuild \
  -project PimPoPom.xcodeproj \
  -scheme 'PimPoPom Owner Ads QA' \
  -configuration OwnerAdsQA \
  -destination 'generic/platform=iOS' \
  -showBuildSettings)
printf '%s\n' "$owner_ads_build_settings" | rg -Fq 'PIMPOPOM_ADS_MODE = owner-real-test'
printf '%s\n' "$owner_ads_build_settings" | rg -Fq 'PIMPOPOM_ADMOB_BANNER_UNIT_ID = ca-app-pub-6428992187280935/3513535878'
printf '%s\n' "$owner_ads_build_settings" | rg -Fq 'PIMPOPOM_ADMOB_INTERSTITIAL_UNIT_ID = ca-app-pub-6428992187280935/5433122203'
printf '%s\n' "$owner_ads_build_settings" | rg -Fq 'PIMPOPOM_ADMOB_TEST_DEVICE_IDS = 65889f215752fbc9ad39e52b00d92987'

release_build_settings=$(xcodebuild \
  -project PimPoPom.xcodeproj \
  -scheme PimPoPom \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -showBuildSettings)
printf '%s\n' "$release_build_settings" | rg -Fq 'CONFIGURATION = Release'
printf '%s\n' "$release_build_settings" | rg -Fq 'PIMPOPOM_ADMOB_APP_ID = ca-app-pub-6428992187280935~3622035442'
printf '%s\n' "$release_build_settings" | rg -Fq 'PIMPOPOM_ADS_MODE = disabled'
if printf '%s\n' "$release_build_settings" | rg -q 'PIMPOPOM_ADMOB_(BANNER_UNIT_ID|INTERSTITIAL_UNIT_ID|TEST_DEVICE_IDS) ='; then
  printf '%s\n' 'Checked-in Release must not contain ad units or test-device identifiers.' >&2
  exit 1
fi

rg -Fq '"identity" : "swift-package-manager-google-mobile-ads"' PimPoPom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rg -Fq '"version" : "13.6.0"' PimPoPom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rg -Fq '"revision" : "7651abff585dc8dacd1744222d5f03bdd2a8532a"' PimPoPom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rg -Fq '"identity" : "swift-package-manager-google-user-messaging-platform"' PimPoPom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rg -Fq '"version" : "3.1.0"' PimPoPom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
rg -Fq '"revision" : "13b248eaa73b7826f0efb1bcf455e251d65ecb1b"' PimPoPom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

if ! xcrun simctl list devices available | rg -Fq 'PimPoPom iPhone 17 ('; then
  printf '%s\n' 'Missing PimPoPom iPhone 17 simulator. Run Scripts/create-alpha-simulators.sh first.' >&2
  exit 1
fi

xcodebuild -quiet \
  -project PimPoPom.xcodeproj \
  -scheme PimPoPom \
  -destination 'platform=iOS Simulator,name=PimPoPom iPhone 17' \
  test
git diff --check
