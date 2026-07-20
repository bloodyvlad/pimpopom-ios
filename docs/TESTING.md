# Testing and quality gates

PimPoPom is a timing-sensitive game with identity, public ranking, ads, and paid value. Simulator-only confidence is insufficient.

## Current alpha evidence — 2026-07-19

- **Unit-tested:** 29 pure Swift checks cover scoring/rounding, phase/grid boundaries, lives/recovery, proof timing/order, deadline equality, multiplier overflow/reset/5× accounting, decoy overlap/expiry/reservation/ignored opportunities, reset behavior, and Zen retention/cadence/manual results. Native app tests additionally cover cosmetics and API contracts, audio lifecycle, preferences, gameplay presentation, server-authoritative Achievements, explicit Game Center opt-in/persistence/handler teardown, exact five-product StoreKit configuration and recovery, account-scoped paid value, strict account deletion, ad environment guards, authoritative account gating, UMP outcomes, teardown, banner states, persistent 2/3/4 cadence, deduplication, no-fill retry, presentation-began reset, and the exact 667-point compact-menu cutoff.
- **Simulator-tested:** all 28 XCUITest paths pass on the named iPhone SE (3rd generation, 2022) Simulator with iOS 26.5 at responsive-layout implementation commit `f4f9be4`. Xcode reported 160 passed tests—132 native unit and 28 UI—with zero failures, zero skips, and zero expected failures; including the separate core package, the full check exercised 189 tests. Zero-network fake paths verify an exact centered 320×50 menu/results creative, compact SE header control, taller-screen bottom-control branch, authoritative ad-free removal of the control and every banner container, absent disabled/ad-free gameplay hosts, stable eligible-run spacing, pushed Settings lifecycle, retained 351-point board geometry, and the required accessible Privacy choices route. The focused taller-menu path also passed on an iPhone 13 mini Simulator; the complete 13 mini/13 Pro matrix was not rerun. Existing paths cover StoreKit, Profile/deletion, Leaderboard/gameplay/onboarding/Achievements, Game Center isolation, Disco, gap handling, Zen, pets, audio, themes, and compact layout. Fixtures are local and prevent Google requests or production mutations.
- **Simulator-inspected:** exact implementation commit `bfbc351` was directly inspected through focused SE XCUITest attachments. The Arcade Your Color swatch displayed the enlarged equal-bounds glyph while the one-cell live-board glyph retained its prior size. Accepted-hit feedback rendered as upright borderless `+929 points` copy at the tap with smaller `Godlike • 200ms` directly below; the second capture showed both lines fading together over the refreshed active cell. The captures remain local Xcode-result evidence at `/tmp/PimPoPom-P029-merged-candidate-attachments/11C20BE9-5DA3-46DE-B493-494147828BC2.png` and `/tmp/PimPoPom-P029-merged-candidate-attachments/A82EF3F3-0BC6-42F0-95FE-E1464CF84723.png`; they were not added to the repository. Rendered 2×2/4×4 glyph bounds are regression-tested but were not manually screenshot-reviewed in this checkpoint.
- **Build-tested:** responsive-layout commit `f4f9be4` builds for generic Debug iOS Simulator with Swift 6 strict concurrency and the resolved Google Sign-In, Google Mobile Ads 13.6.0, and UMP 3.1.0 dependencies. The immediately preceding configuration-equivalent AdMob commit `3c2e461` also built release-optimized Staging and Release destinations; its compiled Release app reported disabled mode and zero-length banner, interstitial, and test-device values. Current ad-mode shell tests and pre-build validation cover Debug demo inventory, Staging's committed owner split plus demo default, Owner Ads QA's registered GMA test-device ID, checked-in disabled Release, controlled live Release, exact package revisions, the real public App ID, 50 current SKAdNetwork entries, no tracking-purpose key, and copied app privacy manifest. The Debug-only **PimPoPom StoreKit Local** scheme also builds with its committed catalog and offline credit flag.
- **Asset-tested:** 86 retained runtime/master/source/licence files pass committed SHA-256 checks; runtime audio format/duration, all approved pet sheet/habitat dimensions, Pancake runtime/source/chroma/alpha retention, Disco texture dimensions/copies, selectable-icon masters/runtime copies, and Jersey 10 registration/copy are validated.
- **Live read-tested:** Hostinger health, HTML, and signed-out session bootstrap returned successfully on 2026-07-19, confirming Season 1, deployed build `20260719-2`, the retained `20260719-1` native ranked-proof compatibility window, and signed-out `wallet: null`, `adFree: false`, and `storeKit: null`. Ranked, StoreKit, deletion, and other authenticated paths are contract-tested without mutating production. No authenticated score, achievement, shop, profile, deletion, StoreKit, or economy write was performed during this checkpoint.
- **Physical install checkpoints:** exact implementation commit `bab07090ccea2a42f34d2ebfc4a176d9bf3b3ef1`, using bundle ID `com.otcsoftware.pimpopom`, was development-signed with team `APX2925X66`, passed strict signature verification, installed, and launched successfully through CoreDevice on the owner's wired iPhone SE (3rd generation) with iOS 26.3. Device inventory reports installed name **PimPoPom**, version 0.1.0 (1). This confirms compilation, signing, packaging, installation, identity, and process launch only. The prior `d3ffd87958d1eba4ca175b2e0590c1b234063072` checkpoint used retired bundle ID `com.otcsoft.pimpopom.alpha`; earlier install/launch checkpoints remain historical evidence.
- **Not yet validated:** direct automated mid-run entitlement-transition teardown, physical review of commit `f4f9be4`, measured 60/120 Hz touch timing, real UMP first-install/revocation flows, owner real-unit **Test mode**, banner/interstitial no-fill and exact third-result cadence on hardware/TestFlight, purchase/refund-driven ad removal, `app-ads.txt`, aggregate archive privacy report/App Store privacy answers, a real authenticated score or achievement claim, signed-in mutations, StoreKit Sandbox purchase/refund/Family Sharing, server notifications, the complete current-batch 13 mini/13 Pro matrix, physical Game Center Connect/Turn Off/account-change behavior, accessibility/Reduce Motion, audio routes/interruptions/Silent switch, haptics, and every live-ad path.

These are implementation-time observations, not release truth. Record structured physical runs with device/iOS/build/commit before describing a feature slice as device-tested.

The current automated exact-commit evidence is for responsive AdMob/UMP layout commit `f4f9be4`, while retained iOS 26.5 screenshots, hashes, configurations, and limitations for visual checkpoints are recorded in [`DESIGN_QA.md`](DESIGN_QA.md).

## Test layers

### Pure core tests

Run without iOS frameworks, network, wall clock, or nondeterministic randomness:

- seeded target/color/cell selection;
- 1×1 → 2×2 → 4×4 progression and phase boundaries;
- target windows, late-game floor, recovery, and endless completion rules;
- every mistake type and exact third-life terminal transition;
- independent overlapping decoys, lifetime bounds, reserved-cell rule, natural-expiry dodge, and clearing without dodge;
- score formula and rounding at 0, threshold-adjacent, deadline-adjacent, and clamped values;
- Godlike/Perfect/Great/Good boundaries from the displayed rounded milliseconds;
- multiplier step weighting, overflow, next-tap activation, 5× cap, mistake reset, and neutral dodge;
- endless Zen, persistent target through mistakes, adaptive delay, no decoys/reward/proof, and ephemeral End run results;
- proof opcode order, timestamps, duplicate resolution, terminal completeness, and size limits.

Use frozen cross-runtime JSON fixtures plus property-based/randomized transition tests. A parity mismatch fails until an accepted decision explains it.

### Gameplay/timing tests

- Presentation is recorded only when a target is visible.
- Original compatible `UITouch.timestamp` is used; fallback is covered deliberately.
- Input exactly at the deadline is late.
- Pre-presentation input is ignored.
- Queued expiry plus input resolves once and cannot remove two lives.
- Multitouch, simultaneous decoy/target input, rapid restart, background, interruption, and scene replacement cannot deliver stale commands.
- Board hit regions match rendered geometry across safe areas, scale factors, Dynamic Type app chrome, and ad host states.
- A tap in an inter-cell visual gap resolves through the nearest rendered cell as a protocol-valid Missed action; Arcade removes one life and plays the shared loss cue, while Zen retains its no-life-loss rule.
- Every accepted hit publishes the engine-authoritative rounded reaction, rating, multiplied award, and tap location. Presentation tests lock `Rating - Nms`, grouped score copy, its 15-point offset, and Great/Good stationary versus Godlike/Perfect Speed Bar motion.
- Disco target and outgoing halo visibility share one deadline and cannot leave a stale target, halo, or tappable region after expiry.
- The board frame never changes during a run because an ad fills, fails, restores, or becomes removed.

Use XCUITest for end-to-end paths and focused UIKit/SpriteKit harnesses or XCTest performance measures for input/render integration. Simulator tests do not close this gate.

### Service and contract tests

- Apple/Google success, cancellation, nonce/state mismatch, wrong audience, expired token, provider revocation, explicit linking, account conflict, logout, refresh, and deletion.
- Keychain first install, update, lock state, restore, loss, reinstall, and account switch.
- API schema, compatibility rejection, maintenance, rate limit, timeout, cancellation, response redaction, and safe retry.
- Ranked start/abandon/finish, duplicate UUID, mismatched retry, cloned trace, review, idempotent completion, offline start, and background abandonment.
- Profile/nickname, top-five and neighboring-rank context, achievements, pets, themes, catalog prices, ownership, debt, and generation behavior.
- App Attest supported/unsupported, key loss, reinstall, stale challenge, counter/replay, and Apple service outage.

Backend integration uses staging and synthetic accounts/data only. Never place production tokens or real proof bodies in fixtures.

### StoreKit tests

Use a committed StoreKit configuration for local deterministic tests and StoreKit Sandbox/TestFlight for real integration:

- product unavailable, localized metadata, success, cancel, pending/Ask to Buy, interrupted purchase, unverified result, and duplicate updates;
- app/server transaction verification, `appAccountToken` match, idempotent credit, server timeout before finish, relaunch recovery, and account switch;
- Remove Ads current entitlement, restore, reinstall/device change, refund/revocation, family sharing if enabled, and ad shutdown;
- coin-pack refund/reversal with unused and already-spent purchased coins;
- earned/purchased split debit, moderation, debt, reset, and reconciliation;
- `total_coins_collected` continues to count eligible run and achievement-reward credits but excludes StoreKit credits;
- no anonymous coin purchase and no client-submitted amount/price/balance.

### Ad and consent tests

- Debug is locked to Google's demo units. Staging selects the committed production units and registered GMA test-device ID only for a matching committed owner fingerprint; every other device receives official demo units with no custom test-device ID. Owner Ads QA is the explicit cable-only production/Test-mode path. Checked-in Release is disabled; controlled live Release rejects demo units and every test-device identifier.
- UMP update/form/privacy-options/not-required/rejected/error/previously-stored paths and no GMA initialization or ad request before `canRequestAds`.
- Authoritative account tri-state: unresolved and server-confirmed ad-free make zero UMP/GMA requests; account switching and entitlement changes restart consent or tear down inventory safely.
- Maximum content rating General, disabled publisher personalization/first-party ID, no ATT/IDFA path, no tracking purpose string, and explicit unresolved child/teen treatment as a release gate.
- Fixed centered 320×50 menu/gameplay/results banner loading, fill/no-fill/failure/background/teardown; 667-point compact-header versus taller bottom-button placement; and copyright clearance. Disabled/ad-free surfaces construct no slot or note. An eligible active Arcade/Zen run hosts the creative only in its frozen footer below the Speed Bar. Add a direct transition path proving that mid-run ad-free teardown removes the ad/accessibility surface, preserves only invisible geometry, and collapses when that run ends, restarts, or leaves gameplay. A current large anchored-adaptive banner is intentionally excluded because its 50–150-point contract cannot fit the accepted 50-point reservation without clipping.
- One persistent deduplicated Arcade/Zen counter at 2/3/4, no count for abandonment, no duplicate terminal count, retained due state after no-fill/presentation failure, reset only when presentation begins, and no interstitial presentation on active play or unrelated lifecycle events.
- UI automation injects `FakeConsentService` and `FakeAdsService`; it never contacts Google. It verifies exact menu/gameplay/results banner geometry, both responsive Remove Ads placements, unresolved/blocked/ad-free/disabled absence, transition-safe host ownership, the fixed active-run footer, and the accessible required Privacy choices action.
- Active-run banners require accidental-click/policy QA and a long-run refresh soak before release.

Physical/TestFlight ad acceptance must record each phone model, OS, build, commit, configuration, account/ad-free state, consent geography/debug setting, and observed creative label. For every selected phone, cover first-install consent, Privacy choices/revocation, menu/results geometry, active-board isolation, Arcade/Zen combined cadence through exactly the third result, no-fill/offline, background/foreground, purchase-driven removal, coin spending, relaunch/reinstall/account switch/restore/refund/revocation, VoiceOver, Dynamic Type, and Reduce Motion. On the owner's phone, verify the committed GMA test-device identifier and require every real-unit creative to visibly say **Test mode** before any touch. Test-mode creatives are safe to click, but ordinary QA should avoid unnecessary clicks. This evidence does not yet exist.

### Audio and haptic tests

- Independent Sound FX, Music, haptic, and volume preferences.
- Disabled category causes no engine creation, file load, decode, cache, or playback work for that category.
- Preload success/failure, skipped unready cue, voice limits, fades, theme switch, stale load rejection, and loop boundaries.
- Launch sting plays only after app activation, never blocks interaction, follows accepted Sound FX/Silent mode policy, and plays at most once per accepted lifecycle.
- Audio session interruption, route change, Siri/call, lock, background, foreground, Bluetooth/headphones, and media from another app.
- Core Haptics availability, engine reset/stopped handlers, user opt-out, Reduce Motion policy, and no-op fallback.

Automated buffer/hash/loudness/seam tests complement, not replace, listening on physical devices.

### UI, accessibility, and localization tests

Cover every screen and important state at minimum/maximum Dynamic Type, VoiceOver, Increase Contrast, Reduce Motion, bold text, light/dark system context where relevant, and supported locales:

- main-menu Remove Ads compact header placement on standard-height 6/7/8/SE screens, full bottom placement on taller screens, and authoritative ad-free absence;
- Buy Coins in Theme Shop and Pet Shop;
- no ad host, placeholder, or note when disabled/ad-free at run start; otherwise a frozen 50-point noninteractive reservation below the Speed Bar and above the safe area without shrinking or shifting the board during that run;
- Zen's normal-size horizontal logo-gradient Any cell plus red infinity, and Arcade's red hearts, retain non-color accessibility labels;
- transparent reaction stamps remain readable over every theme; Great/Good fade in place, while Godlike/Perfect reach the measured Speed Bar before disappearing;
- Reduce Motion supplies an equivalent non-flying Godlike/Perfect transition without changing score or multiplier timing;
- signed-out gating and identity benefits explanation;
- purchase pending/error/restored/refunded states;
- long nickname, long localized product name, large localized StoreKit price, right-to-left layout if supported;
- color-blind glyph consistency and non-color-only information;
- minimum 44×44-point controls and logical VoiceOver order.

Snapshot tests are regression evidence, not a substitute for interactive device inspection.

## Physical device matrix

Before first production release, include at least:

| Class | Purpose |
| --- | --- |
| iPhone SE (3rd generation, 2022), 60 Hz | Primary install target, compact safe area, thermal/performance floor, touch baseline |
| iPhone 13 mini, 60 Hz | Compact notched safe-area and layout validation |
| iPhone 13 Pro, adaptive up to 120 Hz | Frame/touch timing, ProMotion pacing, and refresh-rate transitions |

PimPoPom is iPhone-only for the local alpha. Simulator profiles for all three models provide build and layout evidence only; they cannot validate physical touch latency or 60/120 Hz behavior.

Test current release iOS plus the oldest supported major version. Add current beta OS/Xcode exploratory coverage before its public release, but do not let beta-only behavior define production truth.

Physical gates:

- extended Arcade and Zen play at normal and Low Power Mode;
- 60/120 Hz reaction consistency and deadline race;
- audio mix/latency, launch sting, haptics, interruptions, routes, Silent switch;
- ads/consent/safe-area/accidental touch;
- StoreKit sandbox purchase, pending, restore, refund test where available;
- Sign in with Apple, Google, linking, logout, deletion;
- background/foreground, phone call/Siri, lock/unlock, memory and thermal behavior;
- cold install, update from prior TestFlight build, reinstall, offline first launch.

## Performance and diagnostics

Define numeric budgets during the gameplay prototype and keep them in test configuration. Measure:

- frame pacing at supported refresh rates;
- presentation-to-handler and touch-to-engine transition latency;
- allocations and main-thread work on target presentation/touch;
- memory after repeated theme/audio/run cycles;
- CPU, energy, thermal state, network bytes, audio underruns, and launch time;
- ad SDK and consent initialization cost outside the reaction path.

Use Instruments signposts without including nickname, token, transaction, proof, or other personal/replayable data.

## CI gates

Proposed pipeline:

1. Documentation/link and secret scan.
2. Resolve pinned Swift packages and reject unexpected lockfile change.
3. Format/lint and strict-concurrency build.
4. Pure core plus cross-runtime parity tests.
5. Service/store/ad unit tests with fakes and StoreKit configuration.
6. XCUITest smoke on a pinned Simulator matrix.
7. Archive validation on protected release workflow.
8. Internal TestFlight only after manual approval.

`Scripts/check.sh` becomes the single local equivalent for required non-device checks. Always run `git diff --check` before staging/committing.

## Evidence language

- **Unit-tested:** pure or mocked checks passed.
- **Simulator-tested:** named Simulator/OS paths passed.
- **Device-tested:** named physical model/OS checks passed.
- **TestFlight-tested:** named build and environment passed.
- **Production-verified:** released App Store build and production backend were smoke-tested.

Do not collapse these labels or call a protocol-verified result human verified.
