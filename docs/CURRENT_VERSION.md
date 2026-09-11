# Current version slice

Verified 2026-09-11. Source, hosted deployment and Apple distribution are separate
evidence; later documentation commits do not change the uploaded binary.

## Released beta

| Item | Current truth |
| --- | --- |
| Product | PimPoPom, iPhone/iOS 17+, Swift 6 strict concurrency |
| TestFlight | `1.02 (28)`, VALID, external-eligible |
| Uploaded iOS source | `3922867341c43c732e894805f829559140f5b5e4`, clean Staging archive/export |
| Apple build ID | `707cd113-dc9c-4410-8547-d13afce6dd1a` |
| QA groups | Internal QA and External QA both `IN_BETA_TESTING`; review `APPROVED`; verified at 13:58:51 UTC |
| Notifications | Automatic notification enabled; existing public link unchanged |
| Railway source | `e866409c6571dd08069db76fabcd07d79016a487`; Server/Core identical in the iOS source |
| Railway deployment | `3041f2bb-70f4-4a71-8318-039fb8e6aedb`, SUCCESS, one Amsterdam replica |
| PHP source | `f84dc9218b58bb937326be931f2ee969abed4282`; deployed only to `speedytapper.otcsoft.com`, before iOS upload |
| PHP schema | Ledger 001–024 unchanged; no migration, account or season reset |
| Previous beta | Build 27 remains the rollback reference; v3/v4 PHP replay retained |
| Production App Store | Not submitted or released by this task |

Exact artifacts, checksums and rollback boundaries: [RELEASE](RELEASE.md) and
[Railway record](../Server/DEPLOYMENT_RAILWAY.md). Feature detail: [BUILD28](BUILD28.md).

## Effective gameplay and network contracts

- Arcade: `normal`, compatibility build `20260729-1`, explicit
  `reaction-proof-v5`, proof 3. Legacy omitted ruleset selects v3/proof 2;
  retained v4/proof 3 is unchanged. Ranking, coins and achievements remain PHP-owned.
- Hearts/clocks appear only on the actual 4×4 board. An active 2×2 target across
  40 seconds remains ineligible. Opportunity cadence/effects are unchanged;
  an overdue pickup may appear soon after 4×4 becomes available.
- Arcade alone has clocks, with a theme-matched rewind arrow; hearts match HUD
  artwork in all themes. Zen is local, ephemeral, unranked and unrewarded.
- Multiplayer: `multiplayer-shared-arcade-v2`, protocol 2, gameplay revision 2,
  2–4 seats, at most 900,000 ms. Legacy revision-1 clients use separate rooms.
  One persistent Vapor authority, native WSS and the shared Arcade SpriteKit board.
- One identical board: 1×1, 2×2 after four total correct hits, 4×4 at 40 seconds.
  Owners are random, may repeat, and may overlap on free cells. Waiting for an
  own-color opportunity is intentional. Arcade quiet delays and speed progression
  are shared; cell contention and delivery headroom can extend personal spacing.
- After ten seconds, successful hits rotate assigned colors when safe. Player
  colors stay unique; persistent decoys exclude every player's color and have no
  exclamation marker. Neutral hearts restore one life up to three for the first
  server-admitted claim; losing claims are not mistakes and eliminated seats stay
  spectators. Multiplayer never has clocks, coins, achievements or v2 ranking.
- A valid PHP primary session and confirmed public name suffice; no Game Center
  prerequisite. Session refresh, ordered Leave, connection-generation fencing and
  pushed connected/non-full waiting lists remain. No peer FAST/tap transcript path.
- Results are service-reported, unranked aggregates, not independent PHP replay
  or human verification. The persistent outbox survives restarts; live rooms do not.

## Rooms and UI

Rooms have stable eight-character codes, visible in waiting/live/results screens.
Copy/Share is available in the waiting room. Public rooms support creator-name
substring search; exact case-insensitive code/full UUID can find public or private
joinable rooms. Private rooms never appear in browsing, nickname or partial-code
search. Anyone signed in with the full code may join; no password is required.
The app requires advertised `roomDiscoveryRevision:1` before private creation.
Debounced query/request fencing prevents stale responses from restoring old lists.
On compact phones the roster scrolls while code, Leave, Ready and Start remain
reachable. Logo/Menu, competitive strip and YOU LOSE/SPECTATING are retained.

## Verification and remaining gates

- Final source: 241 app/UI tests, zero failures/skips, plus 89 core and 40 service
  tests. Separate compact iPhone SE all-theme room-control test passed; initial
  cold Simulator clipboard/assertion failures and the passing warm run are retained.
- Four local socket clients completed 92 seconds, 5,480 shared snapshots and
  11,208 decoy-exclusion checks: no color collisions or pre-4×4 hearts, exactly
  one four-way heart winner, and three successful private-code joins.
- Linux ARM64: 40 service/89 core plus startup/readiness checks passed. Local
  AMD64 emulation failed in the Swift compiler; Railway's native AMD64 release
  build and direct x86_64 runtime checks passed. No local AMD64 unit-pass claim.
- PHP: Composer, v5/legacy SQLite and disposable MariaDB checks passed. All 69
  hosted source hashes, unchanged schema/private configuration and 35 HTTPS checks
  verified. Railway: ten WSS boundaries, UID/GID 10001, protected writable outbox,
  unchanged settings/secrets; temporary audit/SSH access removed.
- Archive/export/upload, matching app symbols, 12 privacy manifests and no private
  or test files verified. Vendor Google Ads/UMP dSYM warnings remain accepted.

Evidence: `build/releases/build28-20260911/`. Still validate genuine signed-in
2/3/4-iPhone Wi-Fi/cellular matches, reconnect/logout, heart races, result delivery,
accessibility and 60/120 Hz latency on named hardware. Multi-region failover,
sustained load/draining and production/legal/storefront gates remain open.
No live ads, paid-plan upgrade, new region or account/economy change was performed.
