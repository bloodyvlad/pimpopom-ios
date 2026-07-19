#!/bin/sh
set -eu

mode=${PIMPOPOM_ADS_MODE:-}
app_id=${PIMPOPOM_ADMOB_APP_ID:-}
banner_id=${PIMPOPOM_ADMOB_BANNER_UNIT_ID:-}
interstitial_id=${PIMPOPOM_ADMOB_INTERSTITIAL_UNIT_ID:-}
test_ids=${PIMPOPOM_ADMOB_TEST_DEVICE_IDS:-}
configuration=${CONFIGURATION:-}

demo_banner='ca-app-pub-3940256099942544/2934735716'
demo_interstitial='ca-app-pub-3940256099942544/4411468910'
real_app_id='ca-app-pub-6428992187280935~3622035442'

fail() {
    printf '%s\n' "Ad configuration error: $1" >&2
    exit 1
}

require_production_unit() {
    printf '%s\n' "$1" | rg -q '^ca-app-pub-6428992187280935/[0-9]+$' \
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
        test -z "$test_ids" || fail 'demo mode does not accept private test-device identifiers'
        ;;
    owner-real-test)
        test "$configuration" = 'OwnerAdsQA' || fail 'owner-real-test is restricted to OwnerAdsQA'
        require_production_unit "$banner_id" 'Owner Ads QA banner'
        require_production_unit "$interstitial_id" 'Owner Ads QA interstitial'
        test "$banner_id" != "$demo_banner" || fail 'Owner Ads QA cannot use the demo banner unit'
        test "$interstitial_id" != "$demo_interstitial" || fail 'Owner Ads QA cannot use the demo interstitial unit'
        test -n "$test_ids" || fail 'Owner Ads QA requires an ignored GMA test-device hash'
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
        fail 'mode must be disabled, demo, owner-real-test, or live'
        ;;
esac

if test "$configuration" = 'Staging'; then
    test "$mode" = 'demo' || fail 'Staging is restricted to Google demo inventory'
fi
