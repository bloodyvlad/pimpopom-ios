# Testing and quality gates

PimPoPom is a timing-sensitive game with identity, public ranking, ads, and paid value. Simulator-only confidence is insufficient.

## Current alpha evidence — 2026-07-18

- **Unit-tested:** 29 pure Swift checks cover scoring/rounding, phase/grid boundaries, lives/recovery, proof timing/order, deadline equality, multiplier overflow/reset/5× accounting, decoy overlap/expiry/reservation/ignored opportunities, reset behavior, and Zen retention/cadence/manual results. Sixty-eight native app tests additionally cover cosmetics and API contracts, audio lifecycle, preferences, gameplay presentation, and server-authoritative Achievements. Current additions cover the exact deployed ranked build, genuine engine proof tuples, exact saved-run confirmation, rejection of a mismatched verified entry, fixed score-column content, three-point Your Color geometry, centered Missed/Too slow copy, feedback z-layers, launch-local onboarding state, near-black Disco idle tokens, stronger active glow, and the shared concrete/reflection renderer.
- **Simulator-tested:** all 22 XCUITest paths pass on the named iPhone SE (3rd generation, 2022) Simulator with iOS 26.5 at implementation commit `c0bcc69`. The Xcode result reports 90 passed tests—68 native unit and 22 UI—with zero failures, zero skips, and zero expected failures; including the separate core package, the full check exercised 119 tests. Current paths verify the right-aligned Leaderboard score and absent Legacy chip, absent Achievements balance, one-launch rules-to-slogans transition and cold-launch reset, eligible offline ranked start/finish, and the Disco gameplay surface. Fixtures are local and prevent production mutations. The earlier 15 device-independent paths passed independently on iPhone 13 mini and iPhone 13 Pro at implementation commit `ec71d21`; those profiles were not rerun for the current batch.
- **Simulator-inspected:** implementation commit `c0bcc69` was directly inspected on the SE profile through the final XCUITest attachments. The Leaderboard showed the full right-aligned scores with no Legacy chip, and Disco gameplay showed the vivid active cyan tile, black rounded corners, scratch texture, and visible cyan/violet/red reflected-light surround. Those attachments remain in the local Xcode result and were not added as repository evidence images. Earlier exact-commit evidence remains recorded below, including three-profile captures at `ec71d21`. Parent web commits `923a38e`, `7582b2d`, and `209ee6c` remain the menu/theme, pet, and latest PHP visual references respectively.
- **Build-tested:** the app builds for a generic iOS Simulator with Swift 6 strict concurrency and the resolved Google Sign-In dependency; compiled metadata is asserted to use `com.otcsoftware.pimpopom` plus the registered primary/alternate icons and Change Icon shortcut.
- **Asset-tested:** 86 retained runtime/master/source/licence files pass committed SHA-256 checks; runtime audio format/duration, all approved pet sheet/habitat dimensions, Pancake runtime/source/chroma/alpha retention, Disco texture dimensions/copies, selectable-icon masters/runtime copies, and Jersey 10 registration/copy are validated.
- **Live read-tested:** Hostinger health, signed-out session bootstrap, public Arcade leaderboard, and signed-out achievement catalog returned successfully; the revised in-app Leaderboard decoded and rendered 30 live Arcade results. Ranked finish and achievement claim paths are contract-tested without mutating production. No authenticated score, achievement, shop, profile, or economy write was performed during this checkpoint.
- **Physical install checkpoints:** source commit `64f07f00e504f30388a7b78b429cd2b781708b52`, using bundle ID `com.otcsoftware.pimpopom`, was development-signed with team `APX2925X66`, installed, and launched successfully through CoreDevice on the owner's wired iPhone SE (3rd generation) with iOS 26.3. This confirms the selected identity's compilation, signing, packaging, installation, and process launch only. The prior `d3ffd87958d1eba4ca175b2e0590c1b234063072` checkpoint used retired bundle ID `com.otcsoft.pimpopom.alpha`; earlier install/launch checkpoints remain historical evidence.
- **Not yet validated:** structured physical visual/listening/touch review of implementation commit `c0bcc69`, measured 60/120 Hz touch timing, a new real Google iOS OAuth client for exact bundle `com.otcsoftware.pimpopom`, a real authenticated score or achievement claim, signed-in shop/profile/economy mutations, current-batch 13 mini/13 Pro layout, Game Center integration, accessibility matrix, audio balance/routes/interruptions/Silent switch, haptics, live ads, and StoreKit.

These are implementation-time observations, not release truth. Record structured physical runs with device/iOS/build/commit before describing a feature slice as device-tested.

The current exact-commit evidence for implementation commit `c0bcc69ae907cced24decc1cca140ab96888b640`, plus retained iOS 26.5 screenshots, hashes, configurations, and limitations for earlier commits, is recorded in [`DESIGN_QA.md`](DESIGN_QA.md).

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
