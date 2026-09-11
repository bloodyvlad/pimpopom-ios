# Current version slice

Release baseline verified 2026-09-10; build-28 candidate updated 2026-09-11.
Source, deployment and Apple state are separate evidence.

## Build 28 candidate (not yet uploaded)

Only actual 4×4 boards allow power-ups; Arcade explicitly requests v5/proof 3,
with retained v3/v4 PHP compatibility. Clock artwork includes a counterclockwise
arrow in every theme. Multiplayer adds stable eight-character codes, public
creator-name search and code-only private discovery. The app requires advertised
room-discovery support before private creation. See [BUILD28](BUILD28.md).
PHP verification/deployment must precede the TestFlight upload; the table below
continues to identify the last verified release until the new release is checked.

## Build 27 update

Theme-matched pickup/HUD hearts and Arcade heart/clock power-ups use
`reaction-proof-v4`, proof 3. The compatible PHP verifier was deployed and verified
before the iOS upload; old v3/proof-2 clients remain supported. Multiplayer keeps
revision 2 and hearts only. See [ARCADE_POWERUPS](ARCADE_POWERUPS.md) for rules and
four-player local socket evidence. No migration, account or season reset occurred.

## Released beta

| Item | Current truth |
| --- | --- |
| Product | PimPoPom, iPhone/iOS 17+, Swift 6 strict concurrency |
| TestFlight | `1.02 (27)`, VALID and external-eligible |
| Uploaded iOS source | `753787005b2773e93d02e319ad3713847cf4db0d`, clean before archive/upload |
| Apple build ID | `9e0b4ce6-ea42-4d75-b7f6-b5201932665d` |
| QA groups | Internal QA and External QA both `IN_BETA_TESTING`; beta review `APPROVED`, verified 2026-09-10 |
| Notifications | Existing automatic notification enabled; public-link settings preserved |
| Deployed service source | `6629fe09f31d34584ec39e49e99b49633bf035ea`; no multiplayer runtime change in build 27 |
| Railway deployment | `920bd2bf-217e-44b3-ac4c-d3a0f964b812`, SUCCESS, one Amsterdam replica |
| Deployed PHP source | `0a94f5cfe2a36ae89f0d26db1c72bf7cfe4d683c`; all 69 source hashes and unchanged schema 024 directly verified |
| Previous supported beta | Build 26 / gameplay revision 2, source `6a94d64312b113c8013782aca0a3ea8c8718eaf9` |
| Production App Store | Not submitted or released by this task |

Release/rollback details are in [RELEASE](RELEASE.md) and the
[Railway record](../Server/DEPLOYMENT_RAILWAY.md). Later documentation commits
are not new binaries. Build 24 is historical GameKit/v1; build 20 is an older
rollback reference, not a verified currently installable beta.

## Current contracts

| Area | Effective contract |
| --- | --- |
| Arcade | `normal`, compatibility build `20260729-1`, explicit `reaction-proof-v4`, proof 3; legacy omission selects v3/proof 2 |
| Zen, unchanged | Local, ephemeral, unranked and unrewarded |
| Multiplayer | `multiplayer-shared-arcade-v2`, wire/PHP protocol 2, 2–4 seats, maximum 900,000 ms |
| Gameplay negotiation | Builds 26/27 explicitly require revision 2; omitted revision means legacy 1; browse/join/resume never mix revisions |
| Live authority | One persistent Vapor process and the pure Swift engine; native WSS and shared Arcade SpriteKit renderer |
| Entry | Valid PHP primary session and confirmed public name; no Game Center requirement |
| Results | Service-reported unranked aggregates; no independent PHP replay/human verification claim |
| Rewards/publication | No Multiplayer coins, achievements, v2 ranking or Game Center writes; historical v1 leaderboard reads remain |
| Storage | Persistent result outbox; live rooms remain in memory |

## Multiplayer behavior (builds 26/27)

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
  Preserve the existing competitive strip and themes. Build 27 shares theme-aware
  heart artwork with the HUD; only Arcade receives clock pickups.

Precise rules are in [GAMEPLAY_SPEC](GAMEPLAY_SPEC.md) and
[MULTIPLAYER_V2_REBUILD](MULTIPLAYER_V2_REBUILD.md).

## Verification and remaining gates

- Final iOS source gate: 234 app/UI tests, zero failures/skips, plus 84 core tests.
  Focused accessibility identity/Simulator board-contact collection tests also passed.
  The initial release-gate failure and corrected final result are both retained.
- Four real local socket clients ran for 92 seconds: 5,488 snapshots, zero color
  collisions, 59–68 rotations per player and exactly one four-way heart winner.
  Four Multiplayer theme captures and Arcade heart/clock captures were inspected.
- The feature gate passed 26 service tests. Prior build-26 Linux/runtime checks
  remain historical evidence for the unchanged multiplayer service, not a Linux
  verification of the new Arcade-only code.
- PHP: Composer passed; 111 v4 SQLite, 112 disposable MariaDB and 72 additional
  persisted-path assertions, including legacy defaults and reward idempotency.
  All 69 deployed source hashes, schema 024 and private configuration verified;
  35 live HTTP checks passed. Original workers preserved; audit jobs removed.
- Railway: ten WSS boundary checks passed again. Prior build-26 deployment checks
  established x86_64 PID 1 as UID/GID 10001 with NoNewPrivs and private outbox
  directories mode 0700; these process/volume checks were not repeated for build 27.
- Final archive/export/upload, signature, matching app dSYM, twelve privacy
  manifests and absence of private/test files verified. Apple approved both groups.

Evidence is retained under `build/releases/build27-20260910/` and
`build/powerups-20260910/`; historical build-26 evidence remains separately retained.
Automated/Simulator checks are not physical-device acceptance. Still test genuine
2/3/4-iPhone Wi-Fi/cellular matches, reconnect/logout, heart races, result delivery,
accessibility and 60/120 Hz latency on named hardware. A restart loses live rooms;
multi-region failover, sustained load/draining and production/legal/store gates
remain open. No account/economy reset, paid-plan upgrade or live-ad activation
was performed.
