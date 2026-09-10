# Current version slice

Verified 2026-09-10. Source, deployment and Apple state are separate evidence.

## Unreleased local work

The current branch adds themed pickup/HUD artwork and Arcade hearts/clocks using
`reaction-proof-v4`, proof 3. The PHP compatibility update is local only; it must
be deployed before this client can start ranked Arcade runs. No new TestFlight
build or live service was published for this follow-up. See
[ARCADE_POWERUPS](ARCADE_POWERUPS.md) for rules and four-player test evidence.
The table below identifies the unchanged released build, not the new local source.

## Released beta

| Item | Current truth |
| --- | --- |
| Product | PimPoPom, iPhone/iOS 17+, Swift 6 strict concurrency |
| TestFlight | `1.02 (26)`, VALID and external-eligible |
| Uploaded iOS source | `6a94d64312b113c8013782aca0a3ea8c8718eaf9`, clean before archive/upload |
| Apple build ID | `36664ea8-abbb-4fe2-bfb8-a06783de23c9` |
| QA groups | Internal QA and External QA both `IN_BETA_TESTING`; beta review `APPROVED`, verified 19:40 UTC |
| Notifications | Existing automatic notification enabled; public-link settings preserved |
| Deployed service source | `6629fe09f31d34584ec39e49e99b49633bf035ea`; later iOS lifecycle commit changes no Server/Core code |
| Railway deployment | `920bd2bf-217e-44b3-ac4c-d3a0f964b812`, SUCCESS, one Amsterdam replica |
| Deployed PHP source | `9fe555d179326cecd5e23f0a6a16788b4af0ba34`; additive migration 024 directly verified |
| Previous supported beta | Build 25 / gameplay revision 1, source `962a39de80277534dd45eca56ca913217bde1fbb` |
| Production App Store | Not submitted or released by this task |

Release/rollback details are in [RELEASE](RELEASE.md) and the
[Railway record](../Server/DEPLOYMENT_RAILWAY.md). Later documentation commits
are not new binaries. Build 24 is historical GameKit/v1; build 20 is an older
rollback reference, not a verified currently installable beta.

## Current contracts

| Area | Effective contract |
| --- | --- |
| Arcade, unchanged | `normal`, build `20260729-1`, `reaction-proof-v3`, proof 2 |
| Zen, unchanged | Local, ephemeral, unranked and unrewarded |
| Multiplayer | `multiplayer-shared-arcade-v2`, wire/PHP protocol 2, 2–4 seats, maximum 900,000 ms |
| Gameplay negotiation | Build 26 explicitly requires revision 2; omitted revision means legacy 1; browse/join/resume never mix revisions |
| Live authority | One persistent Vapor process and the pure Swift engine; native WSS and shared Arcade SpriteKit renderer |
| Entry | Valid PHP primary session and confirmed public name; no Game Center requirement |
| Results | Service-reported unranked aggregates; no independent PHP replay/human verification claim |
| Rewards/publication | No Multiplayer coins, achievements, v2 ranking or Game Center writes; historical v1 leaderboard reads remain |
| Storage | Persistent result outbox; live rooms remain in memory |

## Build 26 behavior

- Keep valid primary login while refreshing socket tickets/CSRF. Unknown session
  state shows checking, not a false sign-in requirement. Distinguish service
  failures from logout; reuse healthy foreground sockets.
- PHP retains at most twelve rolling same-session bindings. Valid fresh tickets
  retire oldest credentials; invalid/replayed tickets cannot evict them.
- Push only connected, non-full waiting rooms. Ordered Leave acknowledgments and
  connection generations fence stale responses; finished/abandoned rooms cannot
  block a new valid create. Screen-phase transitions preserve flow ownership.
- One shared board: 1×1, 2×2 after four total correct hits, 4×4 at 40 seconds.
  Owners are random, can repeat, and may overlap on free cells. Waiting is intended.
- Reuse Arcade difficulty and quiet-delay progression. Every correct hit delays
  newly issued targets globally; already announced overlaps remain immutable.
  Contention and transport can extend spacing; exact measured personal cadence
  or sub-frame physical latency is not claimed.
- After ten seconds, successful hits rotate assigned colors when safe. Colors
  remain unique; decoys exclude all player colors and persist across correct taps
  for their Arcade lifetime. Decoys have no exclamation marker.
- Neutral hearts restore one life up to three for the first server-admitted
  claim. Competing claims cause no mistake; eliminated players are not revived.
  PHP 024 preserves cumulative misses above three without changing existing rows.
- Logo/Menu above the board; YOU LOSE/SPECTATING over the continuing match.
  Preserve the existing competitive strip, themes and single-player behavior.

Precise rules are in [GAMEPLAY_SPEC](GAMEPLAY_SPEC.md) and
[MULTIPLAYER_V2_REBUILD](MULTIPLAYER_V2_REBUILD.md).

## Verification and remaining gates

- Final iOS source gate: 225 app/UI tests (220 unit + 5 UI), zero failures/skips,
  plus 72 core tests. Native two-client socket and real hosted-view lifecycle tests
  ran; final themed UI captures were inspected on iPhone 17 / iOS 26.5 Simulator.
- macOS and Linux: 26 service tests; Linux additionally passed 72 core tests and
  unprivileged startup/readiness checks. Local real sockets covered both gameplay
  revisions with 2/3/4 players. A 43-second two-player autoplay verified color
  changes, persistent decoys, 4×4 progression and exactly one heart-race winner.
- PHP: Composer passed; SQLite 122, MariaDB 131, account deletion 56 assertions.
  Live ledger/schema/source hashes and private backups verified; 35 live boundary
  checks passed, original workers preserved, temporary cron jobs removed.
- Railway: ten WSS boundary checks passed. Fresh x86_64 PID 1 identity was
  UID/GID 10001 with NoNewPrivs; private outbox directories are 0700 on the volume.
- Final archive/export/upload, signature, matching app dSYM, twelve privacy
  manifests and absence of private/test files verified. Apple approved both groups.

Evidence is retained under `build/releases/build26-20260910/`.
Automated/Simulator checks are not physical-device acceptance. Still test genuine
2/3/4-iPhone Wi-Fi/cellular matches, reconnect/logout, heart races, result delivery,
accessibility and 60/120 Hz latency on named hardware. A restart loses live rooms;
multi-region failover, sustained load/draining and production/legal/store gates
remain open. No account/economy reset, paid-plan upgrade or live-ad activation
was performed.
