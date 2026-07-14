# Testing and quality gates

PimPoPom is a timing-sensitive game with identity, public ranking, ads, and paid value. Simulator-only confidence is insufficient.

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
- ad host below the Speed streak meter (the requested “speed rating bar”) and above the safe area;
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
| Smallest supported 60 Hz iPhone | Compact safe area, thermal/performance floor, touch/audio baseline |
| Current standard 60 Hz iPhone | Mainstream OS/hardware behavior |
| Supported 120 Hz ProMotion iPhone | Frame/touch timing and refresh-rate transitions |
| iPad sizes, only if universal | Layout, pointer, haptic absence/fallback, multitasking policy |

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
