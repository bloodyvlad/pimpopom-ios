#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
validator="$ROOT/Scripts/validate-ad-configuration.sh"
app_id='ca-app-pub-6428992187280935~3622035442'
demo_banner='ca-app-pub-3940256099942544/2934735716'
demo_interstitial='ca-app-pub-3940256099942544/4411468910'
production_banner='ca-app-pub-6428992187280935/111'
production_interstitial='ca-app-pub-6428992187280935/222'
test_device_hash='0123456789abcdef0123456789abcdef'
owner_idfv_hash='0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
testflight_idfv_hash='abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789'

run_validator() {
    env \
        CONFIGURATION="$1" \
        PIMPOPOM_ADS_MODE="$2" \
        PIMPOPOM_ADMOB_APP_ID="$3" \
        PIMPOPOM_ADMOB_BANNER_UNIT_ID="$4" \
        PIMPOPOM_ADMOB_INTERSTITIAL_UNIT_ID="$5" \
        PIMPOPOM_ADMOB_TEST_DEVICE_IDS="$6" \
        PIMPOPOM_ADMOB_OWNER_BANNER_UNIT_ID="${7:-}" \
        PIMPOPOM_ADMOB_OWNER_INTERSTITIAL_UNIT_ID="${8:-}" \
        PIMPOPOM_OWNER_DEVICE_IDFV_SHA256S="${9:-}" \
        "$validator"
}

expect_failure() {
    if "$@" >/dev/null 2>&1; then
        printf '%s\n' 'Expected unsafe ad configuration to fail.' >&2
        exit 1
    fi
}

run_validator Debug demo "$app_id" "$demo_banner" "$demo_interstitial" ''
run_validator Staging demo "$app_id" "$demo_banner" "$demo_interstitial" ''
run_validator Staging owner-split-test "$app_id" "$demo_banner" "$demo_interstitial" \
    "$test_device_hash" "$production_banner" "$production_interstitial" \
    "$owner_idfv_hash,$testflight_idfv_hash"
run_validator Release disabled "$app_id" '' '' ''
run_validator OwnerAdsQA owner-real-test "$app_id" \
    "$production_banner" "$production_interstitial" "$test_device_hash"
run_validator Release live "$app_id" "$production_banner" "$production_interstitial" ''

expect_failure run_validator Release demo "$app_id" \
    "$demo_banner" "$demo_interstitial" ''
expect_failure run_validator OwnerAdsQA owner-real-test "$app_id" \
    "$production_banner" "$production_interstitial" ''
expect_failure run_validator Staging owner-real-test "$app_id" \
    "$production_banner" "$production_interstitial" "$test_device_hash"
expect_failure run_validator Staging owner-split-test "$app_id" \
    "$demo_banner" "$demo_interstitial" "$test_device_hash" \
    "$production_banner" "$production_interstitial" 'not-a-hash'
expect_failure run_validator Staging owner-split-test "$app_id" \
    "$demo_banner" "$demo_interstitial" "$test_device_hash" \
    "$production_banner" "$production_interstitial" "$owner_idfv_hash,$owner_idfv_hash"
expect_failure run_validator OwnerAdsQA owner-real-test "$app_id" \
    'ca-app-pub-1111111111111111/333' "$production_interstitial" "$test_device_hash"
expect_failure run_validator Release live "$app_id" \
    "$production_banner" "$production_interstitial" "$test_device_hash"
expect_failure run_validator OwnerAdsQA owner-real-test "$app_id" \
    "$production_banner" "$production_interstitial" 'bootstrap-hash-capture'
expect_failure run_validator Debug demo 'placeholder' \
    "$demo_banner" "$demo_interstitial" ''
