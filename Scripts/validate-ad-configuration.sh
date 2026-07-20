#!/bin/sh
set -eu

mode=${PIMPOPOM_ADS_MODE:-}
app_id=${PIMPOPOM_ADMOB_APP_ID:-}
banner_id=${PIMPOPOM_ADMOB_BANNER_UNIT_ID:-}
interstitial_id=${PIMPOPOM_ADMOB_INTERSTITIAL_UNIT_ID:-}
test_ids=${PIMPOPOM_ADMOB_TEST_DEVICE_IDS:-}
owner_banner_id=${PIMPOPOM_ADMOB_OWNER_BANNER_UNIT_ID:-}
owner_interstitial_id=${PIMPOPOM_ADMOB_OWNER_INTERSTITIAL_UNIT_ID:-}
owner_idfv_hashes=${PIMPOPOM_OWNER_DEVICE_IDFV_SHA256S:-}
configuration=${CONFIGURATION:-}

demo_banner='ca-app-pub-3940256099942544/2934735716'
demo_interstitial='ca-app-pub-3940256099942544/4411468910'
real_app_id='ca-app-pub-6428992187280935~3622035442'

fail() {
    printf '%s\n' "Ad configuration error: $1" >&2
    exit 1
}

require_production_unit() {
    printf '%s\n' "$1" | grep -Eq '^ca-app-pub-6428992187280935/[0-9]+$' \
        || fail "$2 must be a PimPoPom production-format ad unit"
}

test "$app_id" = "$real_app_id" || fail 'the real PimPoPom AdMob App ID is required'

case "$mode" in
    disabled)
        test -z "$banner_id" || fail 'disabled mode must not contain a banner unit'
        test -z "$interstitial_id" || fail 'disabled mode must not contain an interstitial unit'
        test -z "$test_ids" || fail 'disabled mode must not contain test-device identifiers'
        ;;
    demo)
        test "$configuration" != 'Release' || fail 'Release cannot use demo ads'
        test "$configuration" != 'OwnerAdsQA' || fail 'Owner Ads QA cannot use demo ads'
        test "$banner_id" = "$demo_banner" || fail 'demo mode requires the reviewed fixed banner demo unit'
        test "$interstitial_id" = "$demo_interstitial" || fail 'demo mode requires the reviewed interstitial demo unit'
        test -z "$test_ids" || fail 'demo mode does not accept test-device identifiers'
        ;;
    owner-split-test)
        test "$configuration" = 'Staging' || fail 'owner-split-test is restricted to Staging'
        test "$banner_id" = "$demo_banner" || fail 'owner split mode requires the demo banner by default'
        test "$interstitial_id" = "$demo_interstitial" || fail 'owner split mode requires the demo interstitial by default'
        require_production_unit "$owner_banner_id" 'Owner split banner'
        require_production_unit "$owner_interstitial_id" 'Owner split interstitial'
        printf '%s\n' "$test_ids" | grep -Eq '^[[:xdigit:]]{32}$' \
            || fail 'owner split mode requires one GMA 32-character hexadecimal test-device hash'
        printf '%s\n' "$owner_idfv_hashes" \
            | grep -Eq '^[[:xdigit:]]{64}(,[[:xdigit:]]{64}){0,3}$' \
            || fail 'owner split mode requires one to four SHA-256 IDFV fingerprints'
        owner_idfv_hash_count=$(printf '%s\n' "$owner_idfv_hashes" | tr ',' '\n' | sort -u | wc -l | tr -d ' ')
        configured_idfv_hash_count=$(printf '%s\n' "$owner_idfv_hashes" | tr ',' '\n' | wc -l | tr -d ' ')
        test "$owner_idfv_hash_count" = "$configured_idfv_hash_count" \
            || fail 'owner split mode requires unique SHA-256 IDFV fingerprints'
        ;;
    owner-real-test)
        test "$configuration" = 'OwnerAdsQA' || fail 'owner-real-test is restricted to OwnerAdsQA'
        require_production_unit "$banner_id" 'Owner Ads QA banner'
        require_production_unit "$interstitial_id" 'Owner Ads QA interstitial'
        test "$banner_id" != "$demo_banner" || fail 'Owner Ads QA cannot use the demo banner unit'
        test "$interstitial_id" != "$demo_interstitial" || fail 'Owner Ads QA cannot use the demo interstitial unit'
        printf '%s\n' "$test_ids" | grep -Eq '^[[:xdigit:]]{32}$' \
            || fail 'Owner Ads QA requires one GMA 32-character hexadecimal test-device hash'
        ;;
    live)
        test "$configuration" = 'Release' || fail 'live ads are restricted to Release'
        require_production_unit "$banner_id" 'Release banner'
        require_production_unit "$interstitial_id" 'Release interstitial'
        test "$banner_id" != "$demo_banner" || fail 'Release cannot use the demo banner unit'
        test "$interstitial_id" != "$demo_interstitial" || fail 'Release cannot use the demo interstitial unit'
        test -z "$test_ids" || fail 'Release cannot contain test-device identifiers'
        ;;
    *)
        fail 'mode must be disabled, demo, owner-split-test, owner-real-test, or live'
        ;;
esac

if test "$configuration" = 'Staging'; then
    test "$mode" = 'demo' || test "$mode" = 'owner-split-test' \
        || fail 'Staging is restricted to demo inventory with an optional owner-device production route'
fi
