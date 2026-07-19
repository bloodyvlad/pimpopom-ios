# Testing and quality gates

PimPoPom is a timing-sensitive game with identity, public ranking, ads, and paid value. Simulator-only confidence is insufficient.

## Current alpha evidence — 2026-07-19

- **Unit-tested:** 29 pure Swift checks cover scoring/rounding, phase/grid boundaries, lives/recovery, proof timing/order, deadline equality, multiplier overflow/reset/5× accounting, decoy overlap/expiry/reservation/ignored opportunities, reset behavior, and Zen retention/cadence/manual results. One hundred thirteen native app tests additionally cover cosmetics and API contracts, audio lifecycle, preferences, gameplay presentation, server-authoritative Achievements, non-blocking Game Center authentication, exact five-product StoreKit configuration, localized product states, acknowledgement-before-finish, unfinished transaction recovery, pending/cancelled/unverified/restore paths, account-scoped transaction isolation, Family Sharing limits, exact two-field PHP credit requests, authoritative wallet/ad-free/refund-debt updates, offline local credit, and strict account-deletion response handling.
- **Simulator-tested:** all 23 XCUITest paths pass on the named iPhone SE (3rd generation, 2022) Simulator with iOS 26.5 at implementation commit `d848653`. Xcode reported 136 passed tests—113 native unit and 23 UI—with zero failures, zero skips, and zero expected failures; including the separate core package, the full check exercised 165 tests. Current paths include the localized StoreKit entry points, binding gates, Restore Purchases, Profile ordering, exact account-deletion confirmation, and existing Leaderboard/gameplay/onboarding/Achievements, Game Center isolation, Disco, gap handling, Zen, pet-follow, audio-control, Theme Shop, and compact-layout coverage. Fixtures are local and prevent production mutations. The earlier 15 device-independent paths passed independently on iPhone 13 mini and iPhone 13 Pro at implementation commit `ec71d21`; those profiles were not rerun for the current batch.
- **Simulator-inspected:** exact implementation commit `bfbc351` was directly inspected through focused SE XCUITest attachments. The Arcade Your Color swatch displayed the enlarged equal-bounds glyph while the one-cell live-board glyph retained its prior size. Accepted-hit feedback rendered as upright borderless `+929 points` copy at the tap with smaller `Godlike • 200ms` directly below; the second capture showed both lines fading together over the refreshed active cell. The captures remain local Xcode-result evidence at `/tmp/PimPoPom-P029-merged-candidate-attachments/11C20BE9-5DA3-46DE-B493-494147828BC2.png` and `/tmp/PimPoPom-P029-merged-candidate-attachments/A82EF3F3-0BC6-42F0-95FE-E1464CF84723.png`; they were not added to the repository. Rendered 2×2/4×4 glyph bounds are regression-tested but were not manually screenshot-reviewed in this checkpoint.
- **Build-tested:** the app builds for generic Debug and Release iOS Simulator destinations with Swift 6 strict concurrency and the resolved Google Sign-In dependency. The Debug-only **PimPoPom StoreKit Local** scheme also builds with its committed catalog and offline credit flag. Compiled metadata is asserted to use display/bundle name **PimPoPom**, identifier `com.otcsoftware.pimpopom`, the registered primary/alternate icons, Change Icon shortcut, and Game Center entitlement; the `.storekit` file is project-only test configuration, not an app resource.
- **Asset-tested:** 86 retained runtime/master/source/licence files pass committed SHA-256 checks; runtime audio format/duration, all approved pet sheet/habitat dimensions, Pancake runtime/source/chroma/alpha retention, Disco texture dimensions/copies, selectable-icon masters/runtime copies, and Jersey 10 registration/copy are validated.
- **Live read-tested:** Hostinger health, HTML, JavaScript, and signed-out session bootstrap returned successfully on 2026-07-19, confirming Season 1, build `20260719-1`, and signed-out `wallet: null`, `adFree: false`, and `storeKit: null`. Ranked, StoreKit, deletion, and other authenticated paths are contract-tested without mutating production. No authenticated score, achievement, shop, profile, deletion, StoreKit, or economy write was performed during this checkpoint.
- **Physical install checkpoints:** exact implementation commit `bab07090ccea2a42f34d2ebfc4a176d9bf3b3ef1`, using bundle ID `com.otcsoftware.pimpopom`, was development-signed with team `APX2925X66`, passed strict signature verification, installed, and launched successfully through CoreDevice on the owner's wired iPhone SE (3rd generation) with iOS 26.3. Device inventory reports installed name **PimPoPom**, version 0.1.0 (1). This confirms compilation, signing, packaging, installation, identity, and process launch only. The prior `d3ffd87958d1eba4ca175b2e0590c1b234063072` checkpoint used retired bundle ID `com.otcsoft.pimpopom.alpha`; earlier install/launch checkpoints remain historical evidence.
- **Not yet validated:** physical review of implementation commit `d848653`, measured 60/120 Hz touch timing, a real authenticated score or achievement claim using the `20260719-1` gate, signed-in shop/profile/account-deletion mutations, StoreKit Sandbox/TestFlight purchase/pending/restore/refund/reversal/Family Sharing on an iPhone, server-notification delivery/reconciliation, current-batch 13 mini/13 Pro layout, live Game Center authentication and server account binding, the disabled server-fed Game Center mirror, accessibility/Reduce Motion matrix, audio balance/routes/interruptions/Silent switch, haptics, and live ads.

These are implementation-time observations, not release truth. Record structured physical runs with device/iOS/build/commit before describing a feature slice as device-tested.

The current automated exact-commit evidence is for implementation commit `d848653`, while retained iOS 26.5 screenshots, hashes, configurations, and limitations for earlier visual checkpoints are recorded in [`DESIGN_QA.md`](DESIGN_QA.md).

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

- Test IDs only in Debug, CI, screenshots, and QA builds.
- UMP update/form/privacy-options/no-consent/error paths and no ad request before permission to request.
- Contextual versus ATT-authorized configuration according to the accepted design.
- Child/teen/region treatment and max creative rating.
- Anchored adaptive sizes, compact/large safe areas, rotation policy, no-fill, refresh, offline, inappropriate-ad report, and Remove Ads transition.
- A filled ad cannot overlap the board or receive a synthetic board tap; board targets do not move.
- If active-run banners are ever approved, add accidental-click/policy QA and a long-run refresh soak before release.

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

- main-menu Remove Ads lower-right placement;
- Buy Coins in Theme Shop and Pet Shop;
- a fixed 50-point ad host below the Speed Bar and above the safe area, without shrinking or shifting the board during a run;
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
