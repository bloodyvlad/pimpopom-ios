# Arcade power-ups — build 27

Build 28 changes only the minimum pickup grid to actual 4×4 via explicit v5/proof
3 and replaces clock artwork with a themed rewind clock. The retained v4 contract
below still governs build 27; see [BUILD28](BUILD28.md) for the current delta.

Owner-requested and released 2026-09-10. Build 27 is VALID and approved for Internal
QA and External QA; the compatible PHP verifier was deployed first. Zen and
Multiplayer timing are unchanged. Exact release evidence is in [RELEASE](RELEASE.md).

## Gameplay

- Arcade uses explicitly selected `reaction-proof-v4`, proof 3. Legacy v3/proof 2
  remains unchanged for old clients and shared baseline rule tests.
- One combined pickup opportunity occurs every random 12–20 seconds. Choose a
  heart or clock randomly, with one live pickup at most and a three-second lifetime.
  Require at least a 2×2 board and two free cells, reserving a cell for targets.
  Blocked opportunities retry after 250 ms. Pickups never overwrite targets/decoys.
- A heart restores one life, capped at three. A full-health claim consumes it.
  No revival, points, hits, streak or color change is awarded by a pickup.
- A clock immediately sets the pace rate to 70%, recovering linearly to 100% over
  ten seconds. Normal elapsed-time/hit-based difficulty progression continues.
  Another clock refreshes the effect; it never multiplies/compounds the slowdown.
- Sample new target/decoy delays and new response windows using inverse rate:
  `ceil(baseMilliseconds * 100000 / rateUnits)`, where
  `rateUnits = 70000 + 3 * clamp(msSinceClockClaimHandled, 0, 10000)`.
  Already sampled delays, visible target deadlines, decoy lifetimes, pickup
  lifetimes, recovery and wall-clock duration remain unchanged.
- A mistake clears pickups and restarts their opportunity after recovery plus
  12–20 seconds. The clock effect continues through nonterminal recovery; run end,
  restart and abandonment clear it. End the run at zero remaining lives, not at
  three cumulative misses.
- Board hearts and HUD lives share the same theme-aware artwork, including Pixel's
  stepped heart. Clock artwork follows the theme; the Speed Bar shows current
  pace percentage during recovery to normal. VoiceOver activates the same board
  contact path as physical touches.

## Input and proof

Pickups use their own first-visible/contact window, not the current target's.
Collection never restarts a waiting target or cancels its pending deadline.
Hide expired pickups immediately, allow a two-render-frame UIKit contact drain,
then commit expiry. After committed expiry/collection, old queued contacts are
harmless; they cannot resurrect the pickup or steal a newer target's contact.
Original touch coordinates use the grid visible at contact across dimension
changes. Stopped runs accept neither frame-driven transitions nor gameplay input;
only an explicit new run resumes them.

V4 retains the v3 opcode 0–6 shapes and adds:

| Opcode | Tuple |
| --- | --- |
| 7 | spawn `[7, at, id, kind, cell, lifetimeMs]`, kind 0 heart / 1 clock |
| 8 | collect `[8, inputAt, handledAt, id, cell]` |
| 9 | expiry `[9, at, id...]` |
| 10 | blocked pickup opportunity `[10, at]` |

The client does not submit life totals or tempo values. PHP derives both from
validated pickup evidence. `POST /api/runs` explicitly sends ruleset/proofVersion;
omitting both preserves legacy v3. Partial/unsupported pairs and mismatching
start/finish contracts are rejected. The new client will not submit power-up
gameplay with an old v3 ticket or silently downgrade a signed-in run to practice.

## Integration and release gates

The PHP changes were released from the isolated worktree
`/Users/vlad/Documents/SpeedyTapper-arcade-powerups`, branch
`codex/arcade-powerups`, commit `0a94f5cfe2a36ae89f0d26db1c72bf7cfe4d683c`.
Existing solo miss storage is already large enough; no migration or account/economy
reset was needed. The exact compatible runtime is deployed to
`speedytapper.otcsoft.com`; all 69 source hashes, schema 024, private configuration
and 35 HTTPS boundary checks were verified before build 27 was uploaded.

The existing leaderboard/achievement/coin policies remain unchanged. V4's extra
lives and slower windows affect score comparability with historical v3 results;
no new season, data reset or retrospective score adjustment is implied.

Multiplayer remains revision 2 with hearts only. A shared-board clock is not a
per-seat cosmetic change: it needs authoritative timing rules, compatible clients
and boundary/reconnect tests. Do not activate it implicitly.

## Evidence

- Four real local WebSocket clients ran for 92 seconds: 5,488 snapshots, zero
  player-color collisions; every player rotated colors 59–68 times. All 11,180
  decoy/player-color checks passed. The board grew 1×1 → 2×2 → 4×4; decoys persisted
  after hits. A four-way heart claim awarded exactly one life without extra misses.
- All four Multiplayer theme screenshots were inspected; HUD and board hearts
  match, Pixel edges stay crisp, and there is no clipping/transparent artwork.
- Live Arcade UI tests collected a heart and clock through actual board taps;
  screenshots show the pickup artwork and recovering pace percentage.
- All 84 pure-core tests pass. Both complete Swift proof fixtures replay to exact
  scores, reactions, lives and timing in PHP. The isolated PHP `composer check`
  and 111 focused SQLite / 112 disposable MariaDB assertions passed; v3's 276
  existing backend assertions also remain unchanged and passing.
- Final build-27 `Scripts/check.sh` passed: 234 app/UI tests, zero failures/skips,
  including the native socket fixture. A new regression keeps accessibility cell
  identities stable across live board changes; the unchanged Simulator heart/clock
  board-contact test passes. All 26 service tests passed in the preceding feature gate.
- Additional full persisted PHP settlement: 72 disposable MariaDB assertions
  passed for v4 goldens, legacy-default v3, eligible rewards and exact retries.
- Gameplay evidence is local sockets and iPhone 17 / iOS 26.5 Simulator, not four
  physical iPhones or measured internet latency. Deployment checks above do not
  establish a positive signed-in production match or ranked result.

Logs, screenshots and the four-client harness are retained under
`build/powerups-20260910/`; final release source, Apple state and corrected
release-gate evidence are under `build/releases/build27-20260910/`.
