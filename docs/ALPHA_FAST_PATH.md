# Local iPhone alpha fast path

Status: Current technical execution track. Commercial, legal, account, backend, ads, and StoreKit work is deferred until local gameplay is stable.

## Goal

Install a local-only native PimPoPom gameplay alpha on the owner's iPhone SE (3rd generation, 2022) by the shortest path, then validate compact layout on iPhone 13 mini and timing on iPhone 13 Pro at 120 Hz.

No Google credential is required for this track. The first device build needs only Xcode local signing: an Apple Account in Xcode, a Personal Team or paid team, a unique development bundle identifier, automatic signing, a trusted USB connection, and Developer Mode on the iPhone.

## What is deliberately deferred

- Google or Apple sign-in, nickname, backend sessions, ranked runs, leaderboards, and durable accounts.
- StoreKit, coin purchases, Remove Ads entitlement, ad SDKs, consent, ATT, and live ad identifiers.
- Coins, achievements, pets, theme shops, and cross-platform persistence.
- Game Center, App Attest, analytics, production CI, TestFlight, and App Store records.
- Final logo, icon, launch sting, theme audio, music, and haptics.
- Commercial ownership, accounting, tax, legal, and storefront work.

The code keeps ads and purchases behind disabled local implementations. Do not add placeholder vendor SDKs: a no-network, no-op boundary is a faster and safer placeholder.

## Ordered steps

### A0 — Bootstrap and install the shell

1. Verify Xcode, Swift, the iOS SDK, and command-line tools. Install XcodeGen 2.45.4 with `brew install xcodegen`; it generates the committed Xcode project but is not linked into the app.
2. Generate an iPhone-only, portrait SwiftUI app named PimPoPom with a pure Swift core package and no third-party runtime packages or capabilities.
3. Build the core tests and app for Simulator.
4. Create SE 2022, iPhone 13 mini, and iPhone 13 Pro Simulator profiles for layout smoke tests. Simulator does not validate real 60/120 Hz touch timing.
5. Connect the SE, trust the Mac, enable Developer Mode, add the Apple Account in Xcode, select its Team under Signing & Capabilities, keep automatic signing enabled, select the SE, and press Run.
6. Confirm cold launch, navigation, portrait layout, background/foreground, and reinstall.

Exit: the signed Bootstrap Alpha opens on the physical SE. Google, backend, ad, and StoreKit setup remain absent.

### A1 — Port the deterministic Arcade core

1. Port frozen configuration and pure helpers from source commit `675551adc715942ce2512c14d396d5d14e763f02`.
2. Port the synchronous state machine with injected monotonic time and randomness: start, target activation, correct/wrong/late/empty taps, three lives, 1.5-second recovery, game over, and snapshots.
3. Preserve 1×1 to 2×2 after four correct taps, 4×4 at 40 seconds, phase windows, score formula, rounded rating thresholds, and streak multiplier behavior.
4. Port deterministic source tests before connecting UI.

Exit: plain Swift tests prove the first Arcade rules without SpriteKit, timers, networking, or storage.

### A2 — Connect the native gameplay scene

1. Add SpriteKit behind `SpriteView`; SpriteKit renders snapshots and forwards timestamped input but owns no scoring rules.
2. Anchor activation to the presentation frame and compare it with the original `UITouch.timestamp` on the same monotonic uptime basis.
3. Resolve touch-versus-expiry exactly once; a touch at the absolute deadline is late. Never calculate gameplay from frame counts, requested FPS, `Timer` callback arrival, or animation duration.
4. Add the minimum local UI: main menu, Arcade HUD, board, game over, restart, and menu.
5. Abandon/freeze a run safely when the app backgrounds; stale scheduled work cannot mutate a new run.

Exit: Arcade is playable offline on the SE with correct hits, mistakes, expiry, scoring, lives, and restart.

### A3 — Complete current local gameplay parity

1. Add independent decoys, 450–750 ms lifetime, 550-point natural dodges, capacity, overlap, and reserved-cell behavior.
2. Complete the Godlike/Perfect streak rules, overflow, next-tap multiplier, 5× cap, and mistake reset.
3. Add Zen: endless play, no lives/decoys/rewards/proof, persistent target through mistakes, 1,000 ms initial cadence moving halfway toward the prior correct reaction, and explicit End Run.
4. Keep proof-event generation as passive local output so later ranked integration does not require an engine rewrite; do not transmit it.
5. Add thin ephemeral results with score, elapsed time, hits/misses/dodges, fastest/average reaction, and rating counts.

Exit: the local alpha contains the current Arcade and Zen rules. Services, economy, shops, and final assets remain deferred.

### A4 — Validate the agreed device matrix

1. SE 2022 (60 Hz): primary compact-layout, signing, touch, lifecycle, and 10-minute stability test.
2. iPhone 13 mini (60 Hz): compact safe-area/layout validation.
3. iPhone 13 Pro (adaptive up to 120 Hz): presentation/touch timing and frame pacing. Frame rate may never alter difficulty or measured elapsed time.
4. Repeat relevant runs with Low Power Mode, Reduce Motion, Limit Frame Rate where supported, interruptions, and background/foreground.
5. Record device model, iOS version, build, commit, configuration, checks, and limitations in `docs/DESIGN_QA.md` and `docs/TESTING.md`.

Exit: local gameplay passes on the physical device matrix. Only then choose the next slice: visual/audio polish or native identity/backend integration.

## Later migration order

After A4, return to the full production plan in `docs/MIGRATION_PLAN.md`. Google Sign-In requires a native iOS OAuth client and compatible backend exchange; it is not needed for local play and is not the only eventual release credential. Ads and StoreKit remain disabled placeholders until their product, server, accounting, and release work is deliberately resumed.
