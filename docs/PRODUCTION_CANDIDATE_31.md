# Production candidate 1.02 (31)

Prepared 2026-09-12 on `codex/production-release`. This is a local candidate,
not an App Store or TestFlight release. The owner authorized preparation with
production ad identifiers before deciding whether to request public review.

## Source and intentional changes

Base build 30: `79b02abc524954547fc49b5f67ca3d587f121c41`.
Reviewed Settings links: `698ca24a0f598e386dc2a2e2f04455e33e31e0b3`.
The candidate adds:

- build number 31;
- Release clearing and validation of dormant owner QA units and IDFV fingerprints;
- no app-owned Release IDFV lookup or identifier diagnostic output;
- accurate live-route diagnostics;
- access to Google-required Privacy Choices for unresolved and ad-free accounts,
  retaining all existing consent/account gates on ad initialization and requests;
- neutral age-band selection before Root startup, with no preselected adult option;
- local age/profile binding, account-change reconfirmation, and Settings correction;
- serialized, generation-fenced consent and ad startup, deferred account services,
  and focused lifecycle regressions;
- first-party privacy declarations for account identifiers, gameplay content,
  purchase history and product interaction, linked for app functionality;
- a selectable test Simulator, preserving the default `PimPoPom iPhone 17` device
  for existing workflows.

The generated Xcode project includes the revised build-phase configuration guard.
No gameplay rules, server contract, SDK version, or paid-value ledger changes.
The interstitial cadence remains **three completed games**; the existing AdMob
unit name does not define that cadence.
The Settings links open Privacy, Terms, Refunds and Support at
`https://www.otcsoft.com/pimpopom-legal/{privacy,terms,refunds,support}.html`.
The coordinating website task published legal version 1.0.1 from source
`6a531adbd740079f25093fe441c0f33a76bd0f1e` (artifact SHA-256
`81ce1c1470779e8a0a1ed64aeae885c50c790d67eb3807b617d6ee315bfe02cd`).
It verified those exact destinations returned HTTP 200,
matched the reviewed legal source, contained no authored analytics/ad scripts or
forms, and sent no Set-Cookie header in direct HTTP checks. Hosting may show an
automatic browser/security check. Simulator checks validate link visibility and
accessibility, not browser destinations.

## Owner-approved age handling

The neutral screen asks for Under 13, 13–15, 16–17 or 18 or older. It asks for no
birthday or country. Unknown and under-13 states do not construct RootView, start
consent/advertising, restore identity, or start StoreKit observation. Legal and
Support links remain available. Choice and confirmed account binding are stored
in local UserDefaults, not the app's cloud preferences or its backend. Google
receives the age-related consent/ad request signals described below.

| Self-declared band | UMP under-age-of-consent flag | GMA age-restricted treatment |
| --- | --- | --- |
| Under 13 / unknown | No consent request | No advertising startup |
| 13–15 | true | child |
| 16–17 | false; normal regional consent flow | teen |
| 18+ | false; normal regional consent flow | unspecified |

Sixteen is a conservative worldwide **product handling threshold**, not a claim
about the legal age of consent in every country. General ad content rating,
publisher personalization disabled and publisher first-party ID disabled remain
in every eligible lane. UMP and GMA receive separate age signals because UMP does
not forward its tag to the ads SDK. See Google's [targeting guidance](https://developers.google.com/admob/ios/targeting)
and [under-consent guidance](https://developers.google.com/admob/ios/privacy/gdpr).

On a resolved different/anonymous account or runtime identity loss, the previous
age choice is cleared and the current player must confirm again. An unresolved
initial offline lookup preserves the declared age and local play/privacy access,
while account uncertainty still prevents GMA startup. Settings shows the current
choice and asks the player to review it when sharing a device; a self-declared
local age choice does not verify who is physically using the device.

Changing age closes ad eligibility and discards inventory synchronously. UMP
updates/forms are serialized, and stale generations cannot present a newly loaded
form or make ads ready. Fresh successful consent for the current policy is required
before ad startup. Production does not call UMP reset, which Google documents as
[testing-only](https://developers.google.com/admob/ios/privacy#reset_consent_state).
Already initialized Google SDKs cannot be uninitialized; physical-device checks
must verify the real SDK behavior during transitions. Application generation and
creative identity guards prevent stale results from attaching/presenting.

StoreKit observation is deferred until current-age/account startup permits it,
after the current policy consent flow. A stable confirmed-account startup key
resumes account services and product loading after an offline lookup recovers,
without repeating startup on ordinary session refreshes.
Stopping it does not erase or finish pending transactions. Recovery stops before
subsequent reads/transactions and normal idempotent recovery resumes when eligible.
Game Center authentication callbacks and auto-link work are suspended on gate close.

## Reproducible local archive boundary

Run `Scripts/check.sh` with no `Config/ReleaseAds.private.xcconfig` present. A named
isolated simulator may be selected with `PIMPOPOM_CHECK_SIMULATOR`; a result bundle
may be selected with `PIMPOPOM_CHECK_RESULT_BUNDLE`. Checked-in Release stays
`disabled` and clears all ad unit, test-device and owner selector fields.

After reviewing and committing exact source, supply the ignored private Release
configuration with mode `live`, the AdMob app ID and the two owner-verified real
units. Leave test-device identifiers, owner units and owner IDFV fingerprints
empty. On 2026-09-12 the coordinating task verified the app and both units directly
in AdMob. Retain the safe checked-in default; never commit the private override.

Archive scheme `PimPoPom`, configuration `Release`, generic iOS device, using the
existing App Store Connect API signing credentials without printing their values.
Export locally with method `app-store-connect`, destination `export`, and automatic
version/build management disabled. Do not use the upload export plist or action.
Keep archives, IPAs, signing logs and API credentials outside synced directories.
Record exact clean Git source, Xcode/SDK versions, effective Release settings,
archive and IPA hashes, app/dSYM UUID correspondence, signed capabilities, and
actual bundled Info.plist/privacy manifests. The final exported IPA must have live
units, no test-device/owner QA identifiers, valid distribution signing and
`get-task-allow=false`.

## First-party privacy declaration

The app-owned manifest now declares User ID, Gameplay Content, Purchase History
and Product Interaction. Each is linked to the user, not used by first-party
systems for tracking, and used for App Functionality. This records established
behavior: nickname/account work in `BackendClient.swift`, ranked proofs and
Multiplayer result storage, StoreKit reconciliation, and saved game/shop choices.
The coordinating review checked the PHP identity, run-submission and StoreKit
services at `ec1b5a7` as well as the iOS and realtime source. Apple's
[manifest guidance](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)
defines these declarations. Required-reason API declarations and all vendor
manifests are preserved. Host diagnostics, Google's age-signal retention and
vendor collection remain separate reconciliation questions; these four entries
are not a claim that the complete product collects only these data types.

## Verification

The final `Scripts/check.sh` gate passed: **95 core tests**, **280 unit tests**
and **17 UI tests**, with zero failures. One native WebSocket test was skipped
because its local fixture service was unavailable. Formatting, asset provenance,
ad-configuration checks, plist lint, generic Simulator Debug build, configuration
assertions and `git diff --check` also passed. The full Simulator xcresult contains
298 cases: 297 passed and one skipped, on the owned iPhone 17 / iOS 26.5 Simulator.
The exact results are retained as `production31-final-gate.xcresult` in the private
candidate evidence package. Physical-device/network/live-ad claims remain limited
as described below.

A fresh complete App Store Connect read before the final source commit returned
29 builds, with build 30 the highest and no build 31. This reserves nothing on
Apple's side and performs no upload.

Earlier evidence is retained separately:
The first focused candidate age-policy run passed 80 tests with zero failures or
skips (AdsController, PurchaseController, GameCenterService). The following focused run passed seven tests (four unit and three native UI),
including offline initial lookup, weak listener lifetime, all eligible band
persistence, neutral/under-13 gating and Settings cancel/correct behavior. These
counts are not the final required gate.
The following required run completed with 291 passed, one tutorial failure and
one skipped test (293 total). The Pixel clock-preview button was below the sticky
footer while XCTest reported it hittable; the UI harness now requires the whole
button inside the unobscured scroll area before tapping. All pace and 44-point
assertions are retained. This run preceded the final offline account-service
recovery fix and is not the final candidate validation.
The corrected focused recovery/tutorial run passed eight tests (six unit and two
UI), with no failures or skips. Its tool response timed out at 300 seconds, but
the completed xcresult and Xcode log both report success; the earlier compile-only
attempt is retained separately. The native WebSocket test was skipped in the
required run because the local MP2_DEV_AUTH=1 service on port 18080 was unavailable.
That skip is not evidence of a successful network integration test.
The pre-age-policy candidate baseline run passed 95 core tests and the generic
Debug build, then its Simulator run was interrupted when the owner expanded scope. Its retained
summary reports 266 passed, one real tutorial timeout, one cancellation and one
skip; that baseline is not a pass.
The historical build-30 stopped gate (259 passed, 3 failed, 1 skipped) is not
reported as a pass and does not validate this candidate. Simulator evidence does
not establish physical-device, live-ad or StoreKit validation.

## Remaining public-review gates

- The published audience is 13+ and the owner selected restricted ads for minors.
  Verify the real UMP/GMA behavior for each band, consent changes and shared-device
  transitions on a named physical device. Country-specific capacity/consent
  obligations remain a legal-review gate; self-declaration is not age verification.
- App Privacy answers must reconcile actual app/backend collection and the exact
  exported SDK manifests. The app now records four established first-party data
  types, while GMA declares tracking Device ID
  despite restrictive runtime settings; do not infer tracking labels from an absent
  ATT prompt, IDFV cleanup, or disabled personalization.
- AdMob remains Requires review/unlinked in the coordinating task's direct check.
  Dashboard consent configuration and live production inventory are not proven by
  successful local signing or an archive.
- Reviewer access for signed-in Multiplayer, purchase review, current legal/trader
  metadata and final storefront review remain separate prerequisites.
- Physical-device ad placement/cadence, consent changes, ad-free transitions, and
  the StoreKit purchase/restore/refund/account-switch matrix need retained evidence.
- Historical gameplay/tutorial, hosted-match, network and accessibility limitations
  must be assessed from their named evidence; no unrelated test failure is waived
  by creating this candidate.

No upload, TestFlight assignment, App Review submission or public release is
performed by this preparation. Build 30 and its source remain untouched.
