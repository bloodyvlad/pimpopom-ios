# Testing and quality gates

PimPoPom is timing-sensitive and handles public identity, paid value, ads, and
peer-consistent ranking. Automated checks are necessary; Simulator evidence is not
physical-device evidence.

## Current release evidence

### Build 21 candidate

- `Scripts/check.sh` passed on 2026-08-10: 69 pure-core tests and 272 native tests
  passed on the named iPhone 17 Simulator, including FAST policy/transport/terminal,
  four-theme shared fly-outs, and the Pixel lower-right back-button tap.
- Archive validation and TestFlight processing must be recorded before beta
  promotion. Physical 2/3/4-device acceptance remains required for FAST acceptance
  or production submission.

### TestFlight 1.02 (20)

- Archive source: `69fe7422719dd4953e90354a2ae3f3c976995db7`.
- Focused `CosmeticsTests` plus `MultiplayerPresentationTests`: 47/47 passed on the
  named PimPoPom iPhone 17 Simulator.
- Waiting-room fixtures passed in Classic, Disco, Light, and Pixel with half-right
  pets, square glyph-aware color cells, and a Pixel glyph-off path. Four-player live
  fixtures passed in all themes; the Pixel Leaderboard fixture was inspected.
- Strict recursive Swift format lint, archive compilation/signing validation, and
  `git diff --check` passed.
- The owner explicitly skipped the final post-spacing UI rerun and complete
  `Scripts/check.sh` for the archive. App Store processing is distribution evidence,
  not replacement behavioral coverage.
- App Store Connect reports VALID, Beta App Review APPROVED, and Internal QA plus
  External QA in beta testing.
- Real 2/3/4-device GameKit, peer timing, settlement, and leaderboard publication
  remain unvalidated for this build.

Build 19 is the beta rollback. Its exact source passed 52 core tests, 14 focused
Multiplayer presentation tests, two focused UI paths, and the complete 224-path
native suite through `Scripts/check.sh`. Its pet-free presentation is not current
build-20 behavior.

## Required local gate

Run from a clean intended checkout:

```sh
Scripts/check.sh
git diff --check
```

The check regenerates the project, enforces Swift format, validates assets/hashes,
privacy and ad configuration, builds the generic Simulator target, checks Staging
version/configuration, runs pure core tests, the native unit suite, and the focused
four-theme Multiplayer/Pixel back-button UI regressions.
Behavior changes require focused tests before the full gate.

## Test layers

### Pure core

- Arcade/Zen phase, grid, response-window, recovery, decoy, scoring, rating,
  multiplier, proof, and terminal boundaries.
- Exact Arcade v3 color-bearing proof tuples and monotonic timestamps.
- Multiplayer manifest/tuple validation, reducer replay, lives/recovery, target and
  dodge rotation, score/streak, placement, snapshot, coordinator planning, sealed
  input frontiers, live resolutions, and terminal drain.
- Seeded/property fixtures only; production randomness is not implied deterministic.

### Gameplay and presentation

- First visible frame anchors Arcade/Zen reaction; original compatible touch time
  resolves exact-deadline, pre-presentation, and expiry races once.
- Recovery, multitouch, rapid restart, lifecycle, scene replacement, board gaps,
  pet following, and ad-host geometry cannot deliver stale/double commands.
- HUD, rating/reaction copy, score grouping, Speed Bar, glyphs, and every theme stay
  synchronized with engine state without changing hit geometry.
- Multiplayer waiting/live/results states cover 2/3/4 seats, pets, colors, names,
  readiness, crowns, elimination, collecting/settled/review, and accessibility.

### API, identity, and economy

- Cookie/CSRF bootstrap, cancellation, stale session generation, errors, rate limit,
  compatibility rejection, and idempotent retry.
- Apple/Google login/register/link/reauth/logout/deletion and provider separation.
- Nickname normalization/availability/save race and authoritative 409.
- Game Center launch authentication, persistent ID, silent reconciliation, deferred
  failure, player/account changes, dashboard reopening, and zero direct Apple writes.
- Ranked Arcade ticket/finish tuple, exact run ID, duplicate/review/quarantine, and
  no silent local downgrade.
- Achievement, theme, pet, wallet, debt, selection, and StoreKit response validation.
- Multiplayer lobby/roster/start/submission/settlement and public leaderboard against
  build `20260729-1` contract.

### StoreKit

Use the committed local StoreKit configuration for deterministic paths and
Sandbox/TestFlight for value integration:

- product metadata, success, cancel, pending, Ask to Buy, unverified, interrupted,
  duplicate, app-account mismatch, and server timeout;
- finish only after verified PHP acknowledgement;
- Remove Ads entitlement/restore/reinstall/refund/Family Sharing;
- coin credit/refund/reversal, earned/purchased split, debt, reset, and no anonymous
  value or client-supplied amount.

### Ads and privacy

- Debug/demo, owner-split Staging, Owner Ads QA, and disabled/live Release guards.
- UMP update/form/privacy-options/error plus zero GMA startup before `canRequestAds`
  and authoritative non-ad-free state.
- Fixed 320×50 menu/gameplay/results host, no board movement, no ad hit leakage,
  mid-run ad-free teardown, no-fill/offline/lifecycle, and no surface when disabled.
- Persistent third-completion interstitial cadence, idempotent terminal counting,
  and reset only on presentation start.
- Privacy manifest/SDK declarations, no ATT path, no secrets, and redacted logs.

### FAST Multiplayer

The full deterministic packet, prediction, evidence, disposition, reorder, host,
latency, and 2/3/4-seat network matrix is defined in
[MULTIPLAYER_FAST_TASK](MULTIPLAYER_FAST_TASK.md). Before build 21 is accepted,
require:

- local acknowledgement p95 at or below 33 ms on 60/120 Hz hardware;
- normal-network canonical application p95 at or below 150 ms;
- zero burst-tap double penalties and zero orphaned evidence;
- exactly one disposition per InputID and byte-identical transcripts;
- sealed-frontier preservation of earlier inputs after fast-copy loss;
- mixed live-wire versions rejected before Ready/start;
- 100% valid settlement across supported loss/reorder/duplicate cases.

## UI and accessibility

Exercise every important state with VoiceOver, larger text, bold text, Increase
Contrast, Reduce Motion, glyphs off, long names/prices, and all themes. Controls are
at least 44×44 points with logical reading order. Reaction feedback must have a
non-motion equivalent. Test compact and tall safe areas; marketing fixtures use
synthetic offline data and cannot touch production accounts, ads, or purchases.

## Physical device matrix

| Device class | Required evidence |
| --- | --- |
| iPhone SE (3rd generation), 60 Hz | Minimum target, compact layout, thermal/touch baseline |
| Compact notched 60 Hz iPhone | Safe areas and compact presentation |
| ProMotion iPhone, up to 120 Hz | Frame pacing, touch timing, refresh transitions |

On the oldest supported and current iOS, cover extended Arcade/Zen, audio routes and
interruptions, haptics, lifecycle, Low Power Mode, UMP/ads, StoreKit Sandbox,
Apple/Google/Game Center identity, deletion, update/reinstall/offline launch, and
accessibility. Multiplayer requires distinct 2-, 3-, and 4-device/account matches,
coordinator/non-coordinator outcomes, reconnect, transcript equality, settlement,
and leaderboard visibility.

Record device, OS, refresh rate, build, commit, configuration, account/ad state,
network profile, result, and artifact location. Never retain secrets or raw identity/
proof data.

## Performance evidence

Use signposts and Instruments for first-visible target, contact-to-engine,
contact-to-local-ack, contact-to-canonical-apply, accepted audio start, frame pacing,
main-thread work, allocation, memory, CPU/energy/thermal, and network bytes. Report
percentiles, not anecdotes. `handledAt` is proof evidence and may be clamped; it is
not a substitute for receipt/feedback telemetry.

## Evidence language

- **Unit-tested:** pure or mocked check passed.
- **Simulator-tested:** named Simulator/OS path passed.
- **Device-tested:** named physical model/OS path passed.
- **TestFlight-tested:** named processed build/environment path passed.
- **Production-verified:** released App Store build and production service were
  smoke-tested.

Never collapse these labels or call a protocol-verified result human-verified.
