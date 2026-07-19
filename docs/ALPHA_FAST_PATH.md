# Local iPhone alpha fast path

Status: Historical owner-only fast path. It remains useful for the original installation/gameplay sequence, but its disabled-StoreKit assumptions were superseded on 2026-07-19 by accepted decision P-031, the deployed paid-value backend, and the native StoreKit implementation recorded in `README.md`. Ads and broader commercial-release work remain deferred.

## Goal

Install a playable native PimPoPom alpha on the owner's iPhone SE (3rd generation, 2022) by the shortest path. Reuse the deployed Hostinger PHP API, players, database, and leaderboards for internal testing, then validate compact layout on iPhone 13 mini and timing on iPhone 13 Pro at 120 Hz.

Google is optional for local play and public leaderboard reads. Ranked play needs one new iOS OAuth client ID for bundle ID `com.otcsoftware.pimpopom`; the existing Web client ID remains the backend audience. An OAuth client created for the retired `com.otcsoft.pimpopom.alpha` identifier must be replaced. The device build also needs Xcode local signing, a trusted USB connection, and Developer Mode on the iPhone.

## What is deliberately deferred

- Sign in with Apple, account linking/deletion, a dedicated native session/build contract, and staging.
- StoreKit, coin purchases, Remove Ads entitlement, ad SDKs, consent, ATT, and live ad identifiers. Existing earned coins and server-authoritative cosmetic spending are in scope; buying coins is not.
- Any new cross-platform achievements persistence contract; the existing PHP catalog and claim flow are implemented for the internal alpha.
- Game Center, App Attest, analytics, production CI, TestFlight, and App Store records.
- Final logo/activation-cue acceptance and haptics. The internal icon, theme audio, Music/Sound FX controls, and activation-cue candidate are implemented but still need physical review.
- Commercial ownership, accounting, tax, legal, and storefront work.

The code keeps ads and purchases behind disabled local implementations. Do not add placeholder vendor SDKs: a no-network, no-op boundary is the current placeholder.

## Current implemented slice

- Full local Arcade/Zen rules, SpriteKit board, menu, HUD, results, restart, background abandonment, bottom ad placeholder, and Remove Ads placeholder.
- Live `GET /api/session` and public Arcade/Zen leaderboard reads.
- Existing Google token exchange, profile/nickname, ranked ticket, abandon, and finish client paths. They activate only after a real iOS OAuth client is supplied and the player confirms a nickname.
- Public theme/pet catalogs and authenticated atomic buy/select/hide/show mutations against the same profile and earned-coin balance. Theme Shop and Pet Shop both expose a deliberately disabled Buy Coins placeholder.
- Public achievement catalog reads plus authenticated, CSRF-protected claims for the existing five PHP goals. Locked/ready/claimed state, rewards, and balance remain server-authoritative.
- Four native theme palettes, retained pet sprites/habitats, the backend-derived special pet, and an owner-approved native Pancake replacement with a glowing blue floor.
- Independent default-on Music and Sound FX using the migrated per-theme suites, plus the shared loss cue and original Pim–Po–Pom activation-cue candidate.
- Exact deployed compatibility constants: API base `https://speedytapper.otcsoft.com`, build `20260718-1`, ruleset `reaction-proof-v2`, proof version 1.
- Google Sign-In 9.2.0 resolved by Swift Package Manager. Ads and StoreKit have no vendor/product configuration.

## Ordered steps

### A0 — Bootstrap and install the shell

1. Verify Xcode, Swift, the iOS SDK, and command-line tools. Install XcodeGen 2.45.4 with `brew install xcodegen`; it generates the committed Xcode project but is not linked into the app.
2. Generate the iPhone-only, portrait PimPoPom project. Swift Package Manager resolves Google Sign-In; it remains inactive while its iOS client ID is the placeholder.
3. Build the core tests and app for Simulator.
4. Create SE 2022, iPhone 13 mini, and iPhone 13 Pro Simulator profiles for layout smoke tests. Simulator does not validate real 60/120 Hz touch timing.
5. Connect the SE, trust the Mac, enable Developer Mode, add the Apple Account in Xcode, select its Team under Signing & Capabilities, keep automatic signing enabled, select the SE, and press Run.
6. Confirm cold launch, navigation, portrait layout, background/foreground, and reinstall.

Exit: the signed alpha opens on the physical SE. Ads and StoreKit remain absent.

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
4. Keep proof-event generation passive for local practice. Transmit it only for a server-issued ranked ticket under P-014.
5. Add thin ephemeral results with score, elapsed time, hits/misses/dodges, fastest/average reaction, and rating counts.

Exit: the alpha contains the current Arcade and Zen rules. The next internal slices add backend compatibility and existing cosmetics/audio; ads, StoreKit, and final asset acceptance remain deferred.

### A3.5 — Enable the existing internal backend

1. Keep the production base URL fixed in the internal alpha and use a cookie-enabled default `URLSession`.
2. Load `/api/session` before mutations and send its CSRF token in `X-SpeedyTapper-CSRF`.
3. Read both public leaderboard modes without authentication.
4. For Google, copy `Config/Local.example.xcconfig` to ignored `Config/Local.xcconfig`, add the new iOS client and reversed-client values, and keep the committed Web server client value unchanged.
5. Send Google `idToken.tokenString` as `credential`; never send access token, email, Google display name, raw Google subject, or a client secret.
6. Require the existing confirmed public nickname before ranked Arcade. Obtain the ticket before the first target, finish with proof tuples only, and abandon on restart/menu/background.
7. If PHP session bootstrap or ranked-ticket preparation fails, block Arcade with retry/menu actions. Never silently run an unsaved Arcade result or upload a locally produced result later.

Exit: public data works immediately; authenticated shared-data/ranked paths work after local Google configuration. No PHP deployment is part of this track.

### A3.6 — Port current cosmetics, earned coins, and audio

1. Read `/api/themes` and `/api/pets`; display server names/prices, profile ownership/selection, and `coinBalance`.
2. Use the existing CSRF/session contract for atomic theme buy/select and pet buy/select/hide/show. Never submit price or balance from Swift.
3. Keep signed-out local theme selection to always-free Default/Disco. Keep Buy Coins as one disabled explanatory sheet because the compatibility backend has no StoreKit credit route.
4. Render native theme palettes and reviewed pet sheets outside the reaction board. Trust only backend `specialPetId`; use the retained native Pancake replacement without changing its backend catalog rules. Freeze presentation choices for the duration of an active run.
5. Port exact theme menu/gameplay/tap assets and shared loss cue into one lazy native audio engine with independent persisted Music/Sound FX controls.
6. Generate the original rising Pim–Po–Pom activation-cue candidate, retain its lossless master/generator, and play it at most once after activation without delaying interaction.
7. Coalesce session bootstrap, reject stale account/profile responses, and serialize all theme/pet economy mutations so a late response cannot restore an old player or balance.

Exit: automated catalogs/action matrices/contracts/assets pass, and the feature build installs on the SE. Physical listening remains required before audio acceptance.

### A3.7 — Port current achievements and reward claims

1. Read `/api/achievements` for the five server goals and display the returned locked, claimable, and claimed state without calculating unlocks in Swift.
2. Claim only a server-returned claimable stable ID through `POST /api/achievements/claim`, exact body `{"id":"<stable-id>"}`, and the current `X-SpeedyTapper-CSRF` token.
3. Treat HTTP 201 as the first claim and HTTP 200 as the idempotent duplicate path. Use the returned `coinBalance`; never add a local reward amount to the balance.
4. Reject malformed responses and any response superseded by a player/session change. Reconcile session/CSRF after 401/403 before a user retry.
5. Refresh after account changes, returning from gameplay, and a new pet purchase so protocol-verified run and first-pet unlocks appear without relaunching.
6. Keep the local five-item definitions as signed-out/error presentation only. They cannot unlock an achievement, claim a reward, or grant value.

Exit: all three achievement states and the first-claim contract are tested; the client also handles the server's idempotent duplicate response, and the themed screen plus menu ready marker pass the SE Simulator fixture. Real authenticated production mutation remains a separate deliberate check.

### A4 — Validate the agreed device matrix

1. SE 2022 (60 Hz): primary compact-layout, signing, touch, lifecycle, and 10-minute stability test.
2. iPhone 13 mini (60 Hz): compact safe-area/layout validation.
3. iPhone 13 Pro (adaptive up to 120 Hz): presentation/touch timing and frame pacing. Frame rate may never alter difficulty or measured elapsed time.
4. Repeat relevant runs with Low Power Mode, Reduce Motion, Limit Frame Rate where supported, interruptions, and background/foreground.
5. Record device model, iOS version, build, commit, configuration, checks, and limitations in `docs/DESIGN_QA.md` and `docs/TESTING.md`.

Exit: local gameplay passes on the physical device matrix. Only then choose the next slice: visual/audio polish or native identity/backend integration.

## Later migration order

After A4, return to the full production plan in `docs/MIGRATION_PLAN.md`. Before external distribution, replace P-014's temporary build compatibility with the native contract proposed in `docs/API_CONTRACT.md`. Ads and StoreKit remain disabled placeholders until their product, server, accounting, and release work is deliberately resumed.
