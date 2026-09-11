# Testing and quality gates

PimPoPom is timing-sensitive and handles public identity, paid value, ads, ranked
Arcade and Multiplayer v2. Automated checks are necessary;
Simulator evidence is not physical-device evidence.

## Build 29 verification and explicit UI exception

Local macOS and Linux ARM64 checks pass: 95 pure-core and 47 service tests. Real
four-client sockets cover final scoring after earlier elimination, last-survivor
continuation, spectator-time exclusion and lobby privacy; retained revision-1/2
socket cases also pass. PHP release `bf0ef1b` passes Composer and the new
94-assertion disposable MariaDB reward/ranking suite plus retained regressions.

The initial `Scripts/check.sh` passed core/static/configuration and generic
Simulator compilation, then ran 265 native tests: **259 passed, six UI tests
failed, zero skipped**. A focused three-test run passed four-player badge layout
and privacy, but failed clock-stamp feedback on the pre-ZStack build.

Final source `199bf48` includes tutorial accessibility (`b3b1473`) and stable stamp
container corrections. Neither was Simulator-retested: the owner explicitly
requested no further rechecks and immediate TestFlight distribution. These are
**implemented, not UI-verified fixes**. Final compact/all-theme tutorial and pickup
acceptance remains incomplete; archive success is not a green final UI gate.
Retained evidence: `build/releases/build29-20260911/qa-status.md`,
`full-initial.xcresult`, `focused-ui-1.xcresult` and their attachments.
See [release state](RELEASE.md) and [remaining QA](MP29_GAMEPLAY_TUTORIALS.md).

## Build 28 verification — historical baseline

The release adds five pure-core regressions (89 total), 14 room-service tests
(40 total), request-fenced native search/private-capability tests, themed rewind
clock render attachments, and all-theme room controls. The exact final source
passed 241 app/UI tests with no failures/skips, plus 89 core tests. The compact SE
all-theme test passed with Ready/Start pinned below a scrolling four-player roster;
all eight captures were inspected. Initial cold clipboard/assertion failures and
the unchanged-source passing warm run are retained in compact-qa.md. No measured
physical touch/network latency is claimed.

The 92-second four-socket run found/joined a private four-player room, checked
5,480 shared snapshots, 11,208 decoy exclusions, no pre-4×4 hearts, and exactly one
four-way heart claimant. PHP v5 passed Composer, 154 disposable MariaDB v5 and
112 retained v4 assertions. Linux ARM64 passed 40 service/89 core and runtime gates;
local AMD64 emulation failed in the compiler, while Railway native AMD64 build and
runtime checks passed. Deployment is separately verified in RELEASE.md.

## Build 27 power-up verification (retained baseline)

The pure-core suite has 84 tests, including Arcade v4/proof-3 complete heart/clock
traces independently replayed by the compatible PHP implementation.
Focused coverage includes three-life caps, cumulative misses, clock refresh and
recovery, immutable active deadlines, pickup expiry/input races, stopped-run
immutability, and delayed pickup contacts across grid expansion. V3 and Zen remain
covered independently; an old v3 ticket cannot start the new client's ranked run.

Four real local WebSocket clients completed the 92-second color/heart scenario;
all four theme captures and native Arcade heart/clock collection were checked on
the iPhone 17 / iOS 26.5 Simulator. This is not four physical-device or internet
latency evidence. See [ARCADE_POWERUPS](ARCADE_POWERUPS.md) and retained artifacts
under `build/powerups-20260910/`. The final build-27 app gate passed 234 tests,
zero failures/skips, including the native socket fixture. Focused coverage also
checks stable accessibility identity and Simulator board-contact taps. All 26 service
tests passed in the preceding feature gate. PHP passed 111 SQLite / 112 MariaDB
power-up assertions plus 72 full persisted-path assertions for proofs, rewards,
legacy defaults and retries. Initial failed and corrected UI evidence are retained.

## Current release evidence

- Build 29's current deployment/Apple state is in RELEASE.md; its incomplete final
  UI gate is recorded above. Earlier passing suites do not certify the latest fixes.
- Historical build 28 is VALID, approved and available to both existing QA groups. PHP v5
  and Railway room discovery were deployed/verified before upload. The exact final
  source gate, compact UI, Linux, 35 PHP HTTPS and ten WSS checks passed as above.
- Prior build 27 passed 234 app/UI and 84 core tests. PHP v4 was deployed first:
  all 69 source hashes, unchanged schema 024 and 35 live HTTP checks verified.
  Ten WSS boundary checks passed against the unchanged Railway revision-2 service.
- Historical build 26 passed 225 app/UI, 72 core and 26 service tests plus
  Linux/runtime checks before its release. Build 28 has its own fresh runtime
  evidence; historical checks alone do not establish current deployment state.
- Revision-2 regressions cover post-hit Arcade quiet windows, color uniqueness,
  persistent non-player-color decoys, first-admitted heart claims, delayed input,
  spectating, session-ticket recovery and pushed joinable room lists. Both legacy
  and new revisions require 2/3/4-client socket coverage and isolated directories.
- Build 25 is the prior revision-1 beta; build 24 is historical GameKit/v1.
  Apple/group evidence and exact retained logs are in [RELEASE](RELEASE.md) and
  [CURRENT_VERSION](CURRENT_VERSION.md). Prior installability and real physical
  acceptance are not inferred from old notes or Simulator checks.

## Required local gate

Run from a clean intended checkout:

```sh
Scripts/check.sh
git diff --check
```

The check regenerates the project, enforces Swift format, validates assets/hashes,
privacy and ad configuration, builds the generic Simulator target, checks Staging
version/configuration, runs pure core tests, the native unit suite, and the focused
four-theme Multiplayer/Pixel back-button and Arcade pickup contact UI regressions.
Behavior changes require focused tests before the full gate.
Build 29's owner-authorized no-rerun exception is recorded above; it does not
change the normal gate or establish production/device acceptance.

## Test layers

### Pure core

- Arcade/Zen phase, grid, response-window, recovery, decoy, scoring, rating,
  multiplier, proof, and terminal boundaries.
- Exact Arcade v3/v4 color-bearing proof tuples, pickup events and monotonic
  timestamps; complete Swift fixtures replayed independently in PHP.
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

The final build-26 run passed 72 core tests, 225 app/UI tests (zero skips,
including real native loopback sockets), and 26 service tests. Exact logs,
Simulator identity and separate PHP evidence are recorded in
[CURRENT_VERSION](CURRENT_VERSION.md#verification-and-remaining-gates). Linux and
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
