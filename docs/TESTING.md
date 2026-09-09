# Testing and quality gates

PimPoPom is timing-sensitive and handles public identity, paid value, ads, ranked
Arcade and an unranked Multiplayer v2 candidate. Automated checks are necessary;
Simulator evidence is not physical-device evidence.

## Current release evidence

- Direct App Store Connect read on 2026-09-08 found build 24 VALID, uploaded
  2026-08-22, with Internal QA and External QA groups. External state was
  `READY_FOR_BETA_SUBMISSION`, not evidence of external testability.
- Uploaded build 24 is the historical GameKit/v1 beta. Today's v2 source has no
  new TestFlight upload/deployment; configured `1.02 (24)` is unchanged.
- Final integrated v2 check counts/logs must be recorded in
  [CURRENT_VERSION](CURRENT_VERSION.md) after the exact candidate runs.
  Build 20 remains the historical rollback reference; current installability
  and physical acceptance are not inferred from old notes.

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
- V2 protocol and shared-board engine: zero-input advancement, random repeats,
  overlapping owners/cell reservation, total-hit grid growth, per-seat Arcade
  boundaries, decoy beneficiary/cap rules, recovery, late correction, generation
  fences, exactly-once receipts, ranking-disabled finish and admission drain.
- Seeded/property fixtures only; production randomness is not implied deterministic.

### Gameplay and presentation

- First visible frame anchors Arcade/Zen reaction; original compatible touch time
  resolves exact-deadline, pre-presentation, and expiry races once.
- Recovery, multitouch, rapid restart, lifecycle, scene replacement, board gaps,
  pet following, and ad-host geometry cannot deliver stale/double commands.
- HUD, rating/reaction copy, score grouping, Speed Bar, glyphs, and every theme stay
  synchronized with engine state without changing hit geometry.
- Multiplayer waiting/live/results states cover 2/3/4 seats, pets, colors, names,
  readiness, crowns, elimination, reconnect, unranked results, and accessibility.

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
- V2 cookie/CSRF ticket capabilities, service-only redemption/validation, logout/
  deletion/reconnect and immutable unranked result intake against separate PHP.
- Historical v1 leaderboard reads validate `peer_consistent_v1` without new v1
  mutations or mixing v2 results.

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

### Multiplayer v2 service and network

Use the shared-core tests, `swift test --package-path Server -j 4`,
`bash Server/Scripts/linux-check.sh` and real local WebSocket harness described in
[Server/README.md](../Server/README.md). Separate PHP owns `composer check`,
disposable MariaDB migration/auth/result tests and account-deletion tests.
Passing one layer does not imply the integrated others passed.

The 2026-09-09 integrated run passed 63 current core tests, 209 app/UI tests
(zero skips, including real native loopback sockets), and 8 service tests.
Exact logs, Simulator identity and separate PHP evidence are recorded in
[CURRENT_VERSION](CURRENT_VERSION.md#verification-and-open-gates). Linux and
physical/public-network evidence must be recorded separately.

Acceptance covers 2/3/4 independent clients, no tap before Start, natural finishes,
Ready revisions, duplicate Start/input, roster churn, bounded late correction,
disconnect/rejoin generations, background/foreground and malformed/slow sockets.
Test authenticated WSS/PHP revocation and outbox idempotency across outage,
restart, conflicting delivery, disk full and deletion. V2 remains unranked.

Local contact-to-feedback within one display frame is a goal, not a measured
claim. Under documented RTT/jitter/loss, measure peer Ready, confirmation, visible
feedback and convergence separately. The service's requested 60 Hz scheduler
does not prove device render or touch latency. Old FAST/seal/transcript tests
are historical, not current v2 acceptance criteria.

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
local/remote seat outcomes, shared-board consistency, personal reconnect,
unranked completion and isolation from historical leaderboard writes.

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
