# Current version slice

Verified 2026-09-11. Source, hosted deployment and Apple distribution are separate
evidence; later documentation commits do not change the uploaded binary.

## Build 29 release state

Build 29 implements final-score Multiplayer outcomes, a fresh v2 leaderboard,
two coins per eligible connected/alive minute, waiting-room privacy editing,
shared pickup feedback and isolated interactive tutorials. PHP/Railway are
verified and Apple approved build 29 for both existing QA groups.

| Item | Current truth |
| --- | --- |
| Product | PimPoPom, iPhone/iOS 17+, Swift 6 strict concurrency |
| TestFlight | `1.02 (29)`, VALID / APP_STORE_ELIGIBLE |
| Uploaded iOS source | `199bf48f6dccbc0b1a3b234dc12aca3977c16a50`, clean optimized Staging |
| Apple build ID | `f8c2710e-c0c6-42be-a570-a18145271a59` |
| QA groups | Internal QA and External QA IN_BETA_TESTING; review APPROVED; verified 2026-09-11 19:02:18 UTC |
| Notifications / public link | Automatic notification enabled; existing external link preserved |
| Railway source | `9b28b210e44919cb6d1719ffb97054ab35764de1` |
| Railway deployment | `9ec61784-391e-4be0-bdbe-deb227487f69`, SUCCESS, one Amsterdam replica |
| PHP source | `bf0ef1b030772872775ab64eaedcbaa1b256e0cf`; only `speedytapper.otcsoft.com` |
| PHP schema | Ledger 001–025; only additive 025 newly applied; season/account/purchased-value data preserved |
| Previous beta | Build 28 is the rollback/reference beta; Arcade v3/v4/v5 retained |
| Production App Store | Not submitted or released by this task |

Exact artifacts, checksums and rollback boundaries: [RELEASE](RELEASE.md) and
[Railway record](../Server/DEPLOYMENT_RAILWAY.md). Feature detail: [MP29](MP29_GAMEPLAY_TUTORIALS.md).

## Build-29 gameplay and network contracts

- Arcade: `normal`, compatibility build `20260729-1`, explicit
  `reaction-proof-v5`, proof 3. Legacy omitted ruleset selects v3/proof 2;
  retained v4/proof 3 is unchanged. Ranking, coins and achievements remain PHP-owned.
- Hearts/clocks appear only on the actual 4×4 board. An active 2×2 target across
  40 seconds remains ineligible. Opportunity cadence/effects are unchanged;
  an overdue pickup may appear soon after 4×4 becomes available.
- Arcade alone has clocks, with a theme-matched rewind arrow; hearts match HUD
  artwork in all themes. Zen is local, ephemeral, unranked and unrewarded.
- Multiplayer: `multiplayer-shared-arcade-v2`, protocol 2, gameplay revision 3,
  2–4 seats, at most 900,000 ms. Revision-1/2 clients use separate original-rule rooms.
  One persistent Vapor authority, native WSS and the shared Arcade SpriteKit board.
- One identical board: 1×1, 2×2 after four total correct hits, 4×4 at 40 seconds.
  Owners are random, may repeat, and may overlap on free cells. Waiting for an
  own-color opportunity is intentional. Arcade quiet delays and speed progression
  are shared; cell contention and delivery headroom can extend personal spacing.
- After ten seconds, successful hits rotate assigned colors when safe. Player
  colors stay unique; persistent decoys exclude every player's color and have no
  exclamation marker. Neutral hearts restore one life up to three for the first
  server-admitted claim; losing claims are not mistakes and eliminated seats stay
  spectators. The last living player keeps scoring until all are out or time expires,
  after input admission drains. Highest final score wins; equal scores share places.
  No premature loss while spectating. Multiplayer has no clocks or achievements.
- A valid PHP primary session and confirmed public name suffice; no Game Center
  prerequisite. Session refresh, ordered Leave, connection-generation fencing and
  pushed connected/non-full waiting lists remain. No peer FAST/tap transcript path.
- Completed competitive revision-3 results enter a fresh global v2 leaderboard
  and earn two coins per cumulative connected/alive minute with separate carry.
  Countdown, disconnection, spectating, tutorial and stale/missing economy generations
  do not mint coins. PHP derives immutable idempotent credits; the client submits no
  amount. Trust is `server_reported_v2`, not independent replay or human verification.
  No old-result backfill or Game Center publication. Outbox survives restarts;
  live rooms do not. Final scores/Menu never wait for receipt/wallet refresh.

## Rooms and UI

Rooms have stable eight-character codes, visible in waiting/live/results screens.
Copy/Share is available in the waiting room. Public rooms support creator-name
substring search; exact case-insensitive code/full UUID can find public or private
joinable rooms. Private rooms never appear in browsing, nickname or partial-code
search. Anyone signed in with the full code may join; no password is required.
Build 29 requires advertised `roomDiscoveryRevision:2`; the host can change privacy
beside the waiting-room code without resetting Ready. Older clients retain discovery 1.
Debounced query/request fencing prevents stale responses from restoring old lists.
On compact phones the roster scrolls while code, Leave, Ready and Start remain
reachable. Logo/Menu and competitive badges remain; elimination shows Spectating,
while Win/Lose/Draw follows final scores. Arcade/Multiplayer have separate safe,
untimed tutorials and remembered opt-outs, replayable from Settings; Zen is unchanged.

## Verification and remaining gates

- Initial native gate: 265 tests, 259 passed, six UI failures, zero skipped.
  Focused badge/privacy checks passed; clock-stamp feedback failed before the final
  correction. Tutorial accessibility and stable stamp-host changes were not
  Simulator-retested, per the owner's explicit no-recheck request. Final UI QA is
  **incomplete**, not green; see [TESTING](TESTING.md) and `qa-status.md`.
- Exact shared source: 95 core/47 service tests pass on macOS and Linux ARM64;
  real local sockets cover last-survivor scoring, final drain and privacy. These
  are not real-account internet matches or physical latency measurements.
- PHP: 73 source hashes, schema 025, unchanged private configuration/workers and
  45 HTTPS checks verified. Railway: 13 WSS/auth boundaries, native x86_64,
  UID/GID 10001, NoNewPrivs and private writable outbox verified; settings unchanged.
- Clean Staging archive, matching app symbols, 12 privacy manifests and absence of
  private/test files verified. Apple upload/export and processing succeeded;
  distribution eligibility/review/group states were checked directly.

Evidence: `build/releases/build29-20260911/`; historical build-28 green results
remain explicitly historical in RELEASE.md. Still validate genuine signed-in
2/3/4-iPhone Wi-Fi/cellular matches, reconnect/logout, heart races, result delivery,
accessibility and 60/120 Hz latency on named hardware. Multi-region failover,
sustained load/draining and production/legal/storefront gates remain open.
No live-ad activation, paid-plan upgrade, new region, account/season reset or
purchased-value change was performed. New eligible Multiplayer rewards are intentional.
