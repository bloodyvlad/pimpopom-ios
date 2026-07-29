# Testing and quality gates

PimPoPom is a timing-sensitive game with identity, public ranking, ads, and paid value. Simulator-only confidence is insufficient.

## Multiplayer candidate acceptance plan — build 1.2 (16)

This section is a release gate, not completed evidence. Fill every placeholder only from the exact clean committed candidate later archived and uploaded.

| Evidence | Required record |
| --- | --- |
| Git/source | Exact integrated commit: **pending** |
| Core/service/UI checks | Commands, counts, and result bundles: **pending** |
| Simulator | Single named iPhone 17/iOS version and exercised paths: **pending** |
| Archive/TestFlight | Version/build, archive checksum, App Store Connect build ID, groups/review: **pending** |
| Physical GameKit | 2-, 3-, and 4-player device/account runs: **pending** |
| Backend | Hostinger Multiplayer compatibility release `20260729-1` |

Automated acceptance must cover:

- exact 2–4-participant manifest validation, unique contiguous seats/colors, UUID/base64url bounds, build/ruleset/protocol/proof gates, and 2,500-event/15-minute caps;
- exact unkeyed integer encoding/decoding for all seven event opcodes, contiguous sequence, nondecreasing `inputAt`/event time, handler-lag bounds, transcript replay, checkpoint restore, and manifest-hash mismatch rejection;
- PHP-parity target/dodge-owner rotation, target interval bounds, per-player recovery/elimination, non-owner miss behavior, decoy color/cell/cap/lifetime/expiry/clear rules, score rounding, multiplier progression/reset, and placement tie breaks;
- coordinator input buffering sorted by `(inputAt, seat, inputSequence)`, the 250 ms watermark, delayed packet arrival, same-timestamp tie order, future activation-plan cancellation, and proof that `handledAt` cannot advance canonical scheduler time;
- REST cookie/CSRF wiring, strict create/join/leave/readiness/roster/start/submission/settlement/leaderboard shapes, unknown/additive response-field handling, auth/nickname/Game Center/fresh-proof gates, expiry, creator transfer, post-start cancellation, idempotent submission, and collecting/settled/review decoding;
- `GKMatchRequest.playerGroup`, exact participant count, deterministic coordinator election, version/match/sender/sequence rejection, reliable hello/roster/clock/input/plan/event/ack/snapshot/finish packets, packet gaps, duplicate packets, reconnect timeout, and fixed-coordinator failure;
- lobby, capacity, waiting-room, readiness, creator-only start, draggable local-presentation pet, live 2/3/4-player strip geometry, color/name/pet/points/multiplier/crown, local touch-contact timestamp bridging, shared tap-tone order, settlement ranks, and Multiplayer leaderboard states;
- zero Multiplayer coin credit, achievement unlock/claim, direct `GKLeaderboard.submitScore`, direct `GKAchievement.report`, or per-tap PHP traffic.

One Simulator can validate deterministic and mocked paths, layout, accessibility, lifecycle, and cancellation. It cannot validate real `GKMatch` matchmaking, persistent player IDs, peer latency/order, GameKit reconnection, multi-device audio synchronization, unanimous transcript submission, Apple publication, or background/foreground behavior across peers.

Before external TestFlight promotion, run clean 2-, 3-, and 4-player matches using distinct physical iPhones and Game Center/PimPoPom profiles. For each run retain version/build/commit, device/iOS/account aliases, lobby capacity/group, coordinator alias, clock samples, packet loss/reconnect actions, transcript hash/event count/duration, each submission state, settlement/result IDs, rank ordering, and later Multiplayer Game Center leaderboard visibility. Include at least:

- creator and non-creator leave while forming, creator transfer, expiry, full lobby, stale Game Center proof, and mismatched PHP/GameKit roster;
- ordinary clean finish, a local/remote miss, all-player elimination, one player backgrounding briefly and recovering by snapshot, bounded recovery failure/cancellation, and no coordinator migration;
- simultaneous/near-simultaneous taps crossing the 250 ms watermark, future plan delivery/cancellation, packet duplicate/gap/reorder, and every peer retaining byte-equivalent transcript tuples;
- pets/crown/tones/points/multipliers staying synchronized without those presentation fields entering the transcript;
- collecting until every exact submission arrives, idempotent retry after interruption, clean settled ranking, and intentionally reviewed/ineligible evidence; and
- no coins or achievements before/after Multiplayer, plus asynchronous PHP publication to `com.otcsoftware.pimpopom.multiplayer.verified`.

Do not call Multiplayer device-tested or TestFlight-tested until this physical evidence exists. Clean settlement may be described only as **protocol-verified, peer-consistent**.

## Build 1.2 (15) gameplay-candidate evidence — 2026-07-29

- `swift test --package-path Packages/PimPoPomCore` passed all 36 deterministic core tests. Focused coverage includes the 70-second multi-decoy boundary, 1,000/3,000 ms lifetime bounds, persistence through hits and subsequent targets, staggered expiry with sibling reservation/next-expiry advancement, expiry immediately before a miss, life-loss cleanup, color exclusion/fallback, recovery input suppression, 5 ms challenge contraction, and the exact proof-v2 target/hit/decoy tuples.
- Focused `xcodebuild test` on the single named iPhone 17 Simulator passed all 54 selected `BackendClientTests` and `GameplayLifecycleTests` with zero failures. This covers the literal SpriteView interaction lock while preparing/recovering, coordinator-level decoy persistence/expiry, rapid recovery taps, exact build/ruleset/proof ticket acceptance, and mismatched-ticket rejection. Result bundle: `/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hgpdhdhlwjuyrybrnevtvnzivund/Logs/Test/Test-PimPoPom-2026.07.29_14-26-32-+0200.xcresult`.
- The complete `Scripts/check.sh` gate then passed project regeneration, strict Swift formatting, asset/source/licence hashes, Info/privacy/ad-configuration guards, the same 36 deterministic core tests, a generic Swift 6 Simulator build, and all 228 native unit/UI tests on the named iPhone 17 Simulator with iOS 26.5. Xcode reported zero failures, skips, or expected failures: 264 checks including the core package. Result bundle: `/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hgpdhdhlwjuyrybrnevtvnzivund/Logs/Test/Test-PimPoPom-2026.07.29_14-32-11-+0200.xcresult`.
- This is exact-commit Simulator evidence, not physical-device validation. At candidate-test time ranked Arcade was retryably gated; Hostinger backend release `20260729-1` subsequently deployed the required build/ruleset/proof tuple. No physical run is inferred from that later backend deployment.

## TestFlight build 1.2 (14) nickname-validation evidence

The owner explicitly requested no Simulator execution for this candidate. Project regeneration, strict formatting, deterministic host-side core checks, asset/configuration/privacy guards, `git diff --check`, a generic-iOS app build, a compile-only generic-iOS test bundle, a clean signed generic-device archive, archive signature/entitlement/configuration inspection, and App Store Connect processing passed. Apple accepted build `0c92c8da-ff91-4c99-9a05-cf7f00984fdd`, approved its Beta App Review, and placed it in both named QA groups. This is not Simulator-tested or device-tested evidence.

The committed service tests cover the exact authenticated POST path, JSON/CSRF headers, Unicode non-space preservation, Unicode whitespace rejection without a network request, available/taken decoding, and an authoritative PATCH `409` after a successful availability result. Profile behavior additionally requires later physical/TestFlight acceptance for the 400 ms cancellation-aware debounce, inline exact taken notice, Save disabled while checking/taken, Save enabled after validation transport failure, unchanged-current-name availability, and a real two-client save race.

## Next-candidate acceptance plan — P-054

Do not describe automatic Game Center reconciliation or the Arcade preparation fix as validated until the exact candidate commit passes:

- launch-time handler installation, already-authenticated adoption, authentication cancellation/restriction/unavailable paths, and repeated-launch idempotency;
- no Game Center network mutation before a primary PimPoPom session exists;
- one automatic challenge/proof/link for each new persistent profile/team/game context, no duplicate for an unchanged successful context, and bounded foreground retry after a deferred failure;
- reset/reconciliation after PimPoPom profile or Game Center player change;
- exact `gamePlayerId` plus `publish: true` contract and proof freshness, while retaining zero direct `GKLeaderboard.submitScore`/`GKAchievement.report` calls;
- a Profile card containing only **Game Center** and **See stats**, with no Connect, Verify, Disable, conflict, reset, queued, held, or delivery-description surface;
- repeatable Game Center dashboard presentation/dismissal;
- Arcade preparation/Get Ready showing an empty Your Color swatch and no color name/glyph, followed by the engine-selected color only after run start; and
- unchanged Zen **Any** presentation.

Run the full check only on the single named iPhone 17 Simulator under P-052. Physical/TestFlight acceptance must then cover Apple's real launch authentication, signed-out play followed by primary login, player/account change, dashboard reopening, and asynchronous PHP/Apple delivery. End-to-end current-profile-wins reassignment cannot pass until the separate PHP task in [`GAME_CENTER_AUTOLINK_PHP_TASK.md`](GAME_CENTER_AUTOLINK_PHP_TASK.md) is reviewed and deployed.

## Current build-12 candidate evidence — 2026-07-27

- `Scripts/check.sh` passed project regeneration, strict Swift formatting, asset/source/licence hashes, Info/privacy/ad-configuration guards, 29 deterministic core tests, the generic Swift 6 Simulator build, and 220 native unit/UI tests on the named iPhone 17 Simulator with iOS 26.5. Xcode reported 220 passed with zero failures or skips: 249 checks including the core package. Result bundle: `/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hejlughidecerddzjroxolkasjul/Logs/Test/Test-PimPoPom-2026.07.27_23-07-55-+0200.xcresult`.
- Focused signed-device automation on the connected iPhone SE (3rd generation) with iOS 26.3 opened the Profile's compact **Stats** action, dismissed Apple's dashboard, reopened it, and dismissed it again in one PimPoPom process. The temporary physical-only test hook was removed after this evidence; the release source retains no device bypass.
- Focused unit/UI coverage confirms Apple's one-authorization login-or-create entry policy, both linked provider rows without residual Link actions, durable-link state resolution when server publication is disabled, delegate-managed dashboard dismissal, and the corrected Privacy Choices inset.
- Live production diagnosis confirmed a durable Game Center binding, publication consent, queued Arcade/achievement work, and the active minute publisher. Apple held the leaderboard row with HTTP `409` / `ENTITY_ERROR.ATTRIBUTE.TYPE` and four achievement rows with HTTP `403` / `FORBIDDEN_ERROR`; no iOS fallback was added. The sanitized backend handoff and safe retry order are in [`GAME_CENTER_BACKEND_BUG_REPORT.md`](GAME_CENTER_BACKEND_BUG_REPORT.md).
- Still required before claiming end-to-end Game Center delivery: the backend developer must deploy the leaderboard score-type correction, retain Apple's full sanitized achievement error detail, resolve the indicated permission/review association, requeue held work in the documented order, and confirm the entries appear in Apple's dashboard.

## Current TestFlight build-11 evidence — 2026-07-27

- `Scripts/check.sh` passed project regeneration, strict Swift formatting, asset/source/licence hashes, Info/privacy/configuration guards, 29 deterministic core tests, the generic Swift 6 Simulator build, and 219 native unit/UI tests on the named iPhone SE (3rd generation, 2022) Simulator with iOS 26.5. Xcode reported zero failures, skips, or expected failures: 248 checks including the core package. Result bundle: `/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hejlughidecerddzjroxolkasjul/Logs/Test/Test-PimPoPom-2026.07.27_15-37-28-+0200.xcresult`.
- Focused coverage includes the supplied exact 50×50 Pixel star, GameKit persistent-scoped-ID refusal, fresh challenge/proof enforcement even when the server reports `mirrorReady`, exact `gamePlayerId`/`publish: true` proof contract, profile/player-scoped runtime verification, **See Stats** availability, nullable/additive status decoding, publication disable, conflict/reauthentication state resolution, retained session/economy state, already-authenticated reconnect without a second callback, immediate cancellation while Connecting, signed-out primary-profile gating, and audio recovery for ended-before-active, missing-end, late nonresumable-end, and route-loss sequences.
- The full UI matrix includes the deterministic screenshot fixture and autoplay interior-tap paths in addition to the existing gameplay, identity, StoreKit, ads/UMP, cosmetics, profile, leaderboard, achievement, and compact-layout paths. The fixture remains Debug/`--uitesting` only and performs no production mutation.
- A live signed-out Hostinger read on 2026-07-25 returned Apple login enabled plus `serverPublicationAvailable: true`, `preReleased: true`, and the complete unlinked Game Center status shape expected by build 10. This proves public response compatibility only; it does not exercise an authenticated challenge, GameKit signature, binding, PHP outbox, or Apple delivery.
- Physical build-9 evidence exposed an Apple-provider ownership conflict and a Game Center ownership conflict. The latter rejected the link before PHP could enable publication or enqueue backfill, which is consistent with Apple Games remaining at 0/1 ranked and 0/5 completed for the currently authenticated Apple player. No client score or achievement submission fallback is permitted.
- Still required on TestFlight/physical hardware: a successful link using the exact owning primary profile, pending-job observation, later Arcade best delivery, five achievement deliveries, Turn Off/cancel/reconnect, held/reset-needed support states, Apple propagation delay, audible menu/gameplay foreground recovery, and the wider physical/ad/StoreKit/accessibility/audio matrix below.

## Retained alpha evidence — 2026-07-19

- **Unit-tested:** 29 pure Swift checks cover scoring/rounding, phase/grid boundaries, lives/recovery, proof timing/order, deadline equality, multiplier overflow/reset/5× accounting, decoy overlap/expiry/reservation/ignored opportunities, reset behavior, and Zen retention/cadence/manual results. Native app tests additionally cover cosmetics and API contracts, audio lifecycle, preferences, gameplay presentation, server-authoritative Achievements, explicit Game Center opt-in/persistence/handler teardown, exact five-product StoreKit configuration and recovery, account-scoped paid value, strict account deletion, ad environment guards, authoritative account gating, UMP outcomes, teardown, banner states, persistent 2/3/4 cadence, deduplication, no-fill retry, presentation-began reset, and the exact 667-point compact-menu cutoff.
- **Simulator-tested:** all 28 XCUITest paths pass on the named iPhone SE (3rd generation, 2022) Simulator with iOS 26.5 at responsive-layout implementation commit `f4f9be4`. Xcode reported 160 passed tests—132 native unit and 28 UI—with zero failures, zero skips, and zero expected failures; including the separate core package, the full check exercised 189 tests. Zero-network fake paths verify an exact centered 320×50 menu/results creative, compact SE header control, taller-screen bottom-control branch, authoritative ad-free removal of the control and every banner container, absent disabled/ad-free gameplay hosts, stable eligible-run spacing, pushed Settings lifecycle, retained 351-point board geometry, and the required accessible Privacy choices route. The focused taller-menu path also passed on an iPhone 13 mini Simulator; the complete 13 mini/13 Pro matrix was not rerun. Existing paths cover StoreKit, Profile/deletion, Leaderboard/gameplay/onboarding/Achievements, Game Center isolation, Disco, gap handling, Zen, pets, audio, themes, and compact layout. Fixtures are local and prevent Google requests or production mutations.
- **Simulator-inspected:** exact implementation commit `bfbc351` was directly inspected through focused SE XCUITest attachments. The Arcade Your Color swatch displayed the enlarged equal-bounds glyph while the one-cell live-board glyph retained its prior size. Accepted-hit feedback rendered as upright borderless `+929 points` copy at the tap with smaller `Godlike • 200ms` directly below; the second capture showed both lines fading together over the refreshed active cell. The captures remain local Xcode-result evidence at `/tmp/PimPoPom-P029-merged-candidate-attachments/11C20BE9-5DA3-46DE-B493-494147828BC2.png` and `/tmp/PimPoPom-P029-merged-candidate-attachments/A82EF3F3-0BC6-42F0-95FE-E1464CF84723.png`; they were not added to the repository. Rendered 2×2/4×4 glyph bounds are regression-tested but were not manually screenshot-reviewed in this checkpoint.
- **Build-tested:** responsive-layout commit `f4f9be4` builds for generic Debug iOS Simulator with Swift 6 strict concurrency and the resolved Google Sign-In, Google Mobile Ads 13.6.0, and UMP 3.1.0 dependencies. The immediately preceding configuration-equivalent AdMob commit `3c2e461` also built release-optimized Staging and Release destinations; its compiled Release app reported disabled mode and zero-length banner, interstitial, and test-device values. Current ad-mode shell tests and pre-build validation cover Debug demo inventory, Staging's committed owner split plus demo default, Owner Ads QA's registered GMA test-device ID, checked-in disabled Release, controlled live Release, exact package revisions, the real public App ID, 50 current SKAdNetwork entries, no tracking-purpose key, and copied app privacy manifest. The Debug-only **PimPoPom StoreKit Local** scheme also builds with its committed catalog and offline credit flag.
- **Asset-tested:** 86 retained runtime/master/source/licence files pass committed SHA-256 checks; runtime audio format/duration, all approved pet sheet/habitat dimensions, Pancake runtime/source/chroma/alpha retention, Disco texture dimensions/copies, selectable-icon masters/runtime copies, and Jersey 10 registration/copy are validated.
- **Live read-tested:** Hostinger health, HTML, and signed-out session bootstrap returned successfully on 2026-07-19, confirming Season 1, deployed build `20260719-2`, the retained `20260719-1` native ranked-proof compatibility window, and signed-out `wallet: null`, `adFree: false`, and `storeKit: null`. Ranked, StoreKit, deletion, and other authenticated paths are contract-tested without mutating production. No authenticated score, achievement, shop, profile, deletion, StoreKit, or economy write was performed during this checkpoint.
- **Physical install checkpoints:** exact implementation commit `bab07090ccea2a42f34d2ebfc4a176d9bf3b3ef1`, using bundle ID `com.otcsoftware.pimpopom`, was development-signed with team `APX2925X66`, passed strict signature verification, installed, and launched successfully through CoreDevice on the owner's wired iPhone SE (3rd generation) with iOS 26.3. Device inventory reports installed name **PimPoPom**, version 0.1.0 (1). This confirms compilation, signing, packaging, installation, identity, and process launch only. The prior `d3ffd87958d1eba4ca175b2e0590c1b234063072` checkpoint used retired bundle ID `com.otcsoft.pimpopom.alpha`; earlier install/launch checkpoints remain historical evidence.
- **Not yet validated:** direct automated mid-run entitlement-transition teardown, physical review of commit `f4f9be4`, measured 60/120 Hz touch timing, real UMP first-install/revocation flows, owner real-unit **Test mode**, banner/interstitial no-fill and exact third-result cadence on hardware/TestFlight, purchase/refund-driven ad removal, `app-ads.txt`, aggregate archive privacy report/App Store privacy answers, a real authenticated score or achievement claim, signed-in mutations, StoreKit Sandbox purchase/refund/Family Sharing, server notifications, the complete current-batch 13 mini/13 Pro matrix, physical automatic Game Center launch/authentication/current-player reassignment behavior, accessibility/Reduce Motion, audio routes/interruptions/Silent switch, haptics, and every live-ad path.

These are implementation-time observations, not release truth. Record structured physical runs with device/iOS/build/commit before describing a feature slice as device-tested.

The current automated exact-commit evidence is for responsive AdMob/UMP layout commit `f4f9be4`, while retained iOS 26.5 screenshots, hashes, configurations, and limitations for visual checkpoints are recorded in [`DESIGN_QA.md`](DESIGN_QA.md).

## Test layers

### Pure core tests

Run without iOS frameworks, network, wall clock, or nondeterministic randomness:

- seeded target/color/cell selection;
- 1×1 → 2×2 → 4×4 progression and phase boundaries;
- target windows, 5 ms late-game contraction/floor, recovery input lock, and endless completion rules;
- every mistake type and exact third-life terminal transition;
- 1–3-second independent decoys, the 70-second overlap boundary, persistence across hits/targets, reserved-cell and color-exclusion rules, natural-expiry dodges, and life-loss clearing without a dodge;
- score formula and rounding at 0, threshold-adjacent, deadline-adjacent, and clamped values;
- Godlike/Perfect/Great/Good boundaries from the displayed rounded milliseconds;
- multiplier step weighting, overflow, next-tap activation, 5× cap, mistake reset, and neutral dodge;
- endless Zen, persistent target through mistakes, adaptive delay, no decoys/reward/proof, and ephemeral End run results;
- proof-v2 color-bearing target/hit/decoy tuples, opcode order, timestamps, duplicate resolution, terminal completeness, and size limits.
- Multiplayer manifest/tuple validation, deterministic state replay, target/dodge rotation, 1–3-second decoys, per-player lives/recovery, score/multiplier parity, placement, checkpoint restore, coordinator planning, and the 250 ms input-reorder watermark.

Use frozen cross-runtime JSON fixtures plus property-based/randomized transition tests. A parity mismatch fails until an accepted decision explains it.

### Gameplay/timing tests

- Presentation is recorded only when a target is visible.
- Original compatible `UITouch.timestamp` is used; fallback is covered deliberately.
- Input exactly at the deadline is late.
- Pre-presentation input is ignored.
- Arcade preparation and Get Ready expose no reset/default target color; the Your Color name, glyph, fill, and color-specific outline appear only after the engine starts that run. Zen keeps its intentional **Any** preview.
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
- Game Center launch authentication, already-authenticated adoption, cancellation/restrictions/unavailability, persistent-ID refusal, automatic primary-profile reconciliation, exact-context deduplication, profile/player reset, deferred foreground retry, and zero direct score/achievement submission.
- Game Center API compatibility while the old PHP service can still return recent-auth/conflict errors, plus current-profile-wins reassignment, publication-lock ordering, stale-outbox invalidation, and idempotent authoritative backfill after the separate backend task deploys.
- Multiplayer lobby/leaderboard/create/show/join/leave/readiness/roster/start/submission/settlement compatibility against backend release `20260729-1`, including cookie/CSRF, ten-minute Game Center proof freshness, strict request fields, idempotent retry, and collecting/settled/review states.
- GameKit Multiplayer transport envelope, exact `playerGroup`/participant count, persistent-ID roster mapping, coordinator election, clock estimation, reliable sequence/acknowledgement, future plans, canonical events, snapshots, gaps, duplicates, reconnect, and cancellation.
- Keychain first install, update, lock state, restore, loss, reinstall, and account switch.
- API schema, compatibility rejection, maintenance, rate limit, timeout, cancellation, response redaction, and safe retry.
- Ranked start/abandon/finish, exact `20260729-1`/`reaction-proof-v3`/proof-2 ticket gating, duplicate UUID, mismatched retry, cloned trace, review, idempotent completion, offline start, and background abandonment.
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
- Multiplayer unavailable/login/nickname/Game Center gates; empty/full/expired lobby lists; 2/3/4-player capacity selection; waiting-room readiness/creator start; player-strip fractions; pets/colors/names/points/multipliers/crown; collecting/settled/review results; and leaderboard context;
- purchase pending/error/restored/refunded states;
- long nickname, long localized product name, large localized StoreKit price, right-to-left layout if supported;
- color-blind glyph consistency and non-color-only information;
- minimum 44×44-point controls and logical VoiceOver order.

Snapshot tests are regression evidence, not a substitute for interactive device inspection.

### App Store screenshot fixture

Debug builds expose an offline screenshot fixture only when both `--uitesting` and
`--screenshot-mode` are present. It can open the menu, Theme Shop, Pet Shop,
Leaderboard, signed-out Profile, Achievements, Arcade, or Zen with an owned
theme/pet catalog and an optional selected pet. Leaderboard names and results are
synthetic, distinct, and used only for marketing/test captures.
`--screenshot-autoplay` follows the live target through the normal gameplay input
path at a seeded random interior point rather than the cell center, including
pet-facing updates. It uses seeded reaction delays of 190–280 ms for 1×1,
270–350 ms for 2×2, and 310–500 ms for 4×4. On a menu fixture with a selected pet
it also alternates synthetic left/right taps so the capture shows the same
directional sprite behavior as a real menu tap and does not fall asleep.

Run the complete screenshot and RocketSim video sequence against an already-built
Debug simulator app:

```sh
Scripts/capture-screenshot-fixtures.sh \
  SIMULATOR_UDID \
  6.9-inch \
  /absolute/output/directory
```

The script retains multiple gameplay candidates because the target, reaction
feedback, and pet frame animate independently. Visually select the strongest
frame instead of treating the first timed capture as release truth. RocketSim
records several short 60 fps MP4 clips instead of one long capture because its
CLI transports the finalized media through a bounded IPC message. The script
opts this fixture into app audio; ordinary UI tests remain silent. The RocketSim
CLI currently has no separate audio switch, so audio availability is verified
from the resulting media stream rather than assumed from the command line.
Fixture activation is disabled in non-Debug builds and does not alter production
accounts, wallets, scores, purchases, consent, or advertising.

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
- distinct 2-, 3-, and 4-player Game Center/PimPoPom account sets for real `GKMatch`, peer ordering, background/reconnect, unanimous transcript submission, settlement, and later server-published Multiplayer leaderboard visibility.

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
