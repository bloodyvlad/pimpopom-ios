# Current gameplay specification

Arcade/Zen rules are retained. Multiplayer v2 below is an owner-approved local
candidate, not the uploaded build-24 v1 beta. Presentation and economy cannot
silently change rules; release evidence is separate in CURRENT_VERSION.md.

## Modes

### Arcade

- Wire identifier `normal`; player-facing name **Arcade**.
- Endless until exactly three mistakes.
- Wrong color, decoy, inactive/empty space, and expired correct target are mistakes.
- Mistakes reset the multiplier. The first two start 1.5 seconds of recovery;
  board input during recovery is ignored. The third ends the run immediately.
- A signed-in profile with a confirmed nickname must receive a matching ranked
  ticket before the first target. Session/ticket failure blocks with retry/menu.
- Signed-out or unconfirmed players may play local practice only; it cannot become
  ranked later.

### Zen

- Endless local, unranked, no-coin practice.
- No lives, deadline, decoy, ticket, proof, leaderboard write, achievement, or
  durable history. A mistake leaves the current target visible.
- Target quiet delay starts at 1,000 ms. After a correct reaction:
  `nextDelay = previousDelay + 0.5 × (reactionMs - previousDelay)`.
- **End run** freezes an ephemeral local Results view. Restart/menu/app termination
  discards it.

### Multiplayer v2 — local unranked candidate

- Exactly 2–4 players, fixed unique colors; `multiplayer-shared-arcade-v2`,
  protocol 2. Primary sign-in and confirmed nickname; no Game Center requirement.
- The owner confirmed **one identical shared board**, accepting waits for an
  own-color opportunity on 1×1. Random owner arbitration permits repeats; targets
  overlap only when different cells are available. There is no fixed turn order.
- Start at 1×1; grow to 2×2 after four total valid hits and 4×4 at 40 seconds.
  Shared Arcade numerical configuration/scoring remains authoritative; personal
  target spacing can increase due to contention and delivery headroom.
- Only an owner can hit a target. Wrong-color, empty/gap or trap taps cost only
  the tapping seat's life and cannot consume another seat's target.
- Each seat has three lives, score, streak, multiplier, reactions and 1.5-second
  recovery. Eliminated seats spectate; disconnect has 15 seconds to return while
  other seats continue. All-out or 15 minutes ends play after admission drains.
- Marked traps use another participant's color and are unscorable by every seat.
  Natural expiry grants one beneficiary the unmultiplied 550-point dodge. A global
  Arcade cap reserves capacity for connected living targets; it is not multiplied
  by player count. Correct hits preserve decoys; personal mistakes clear that
  seat's decoys without credit. Trap markers remain visible with glyphs off.
- The persistent Swift service, not peers, derives scores/lives using the same
  pure rules. The app projects local feedback and reconciles receipts/snapshots.
  PHP stores isolated service-reported unranked aggregates, not replayed v2 proof.
- No coins, achievements, v2 ranked season/leaderboard or Game Center publication.
  Historical v1 leaderboard rows remain separate and read-only in the new client.

The complete shared-board adaptations, input admission boundaries and remaining
acceptance work are in [MULTIPLAYER_V2_REBUILD](MULTIPLAYER_V2_REBUILD.md).
They do not promise exact independent Arcade cadence, measured latency, or a
hosted/physically validated service. Arcade's changing player-color rule below
does not apply to the fixed seat colors in v2.

## Arcade/Zen board progression

```text
if elapsedMs >= 40,000: grid = 4×4
else if correctHits >= 4: grid = 2×2
else: grid = 1×1
```

| Phase | Response | Target quiet | Decoy opportunity | Live decoys |
| --- | ---: | ---: | ---: | ---: |
| 0–10 s | 1,000 ms | 550–1,100 ms | none | 0 |
| 10–20 s | 1,000 ms | 550–1,000 ms | 2,200–3,600 ms | 1 |
| 20–30 s | rounded 1,000→750 ms | 500–950 ms | 2,000–3,200 ms | 1 |
| 30–40 s | 750 ms | 475–900 ms | 600–3,400 ms | 1 |
| 40–50 s | 1,000 ms | 525–950 ms | 2,200–3,400 ms | 1 |
| 50–70 s | `max(200, 1000 - 5×challengeHits)` | formula below | formula below | 1 |
| 70 s+ | same | formula below | formula below | `min(6, 2+tier)` |

At the first target at/after 50 seconds, freeze the hit count as the challenge
baseline, then:

```text
challengeHits = hits - challengeBaselineHits
tier = floor(challengeHits / 10)
targetMin = max(250, 425 - 15×tier)
targetMax = max(500, 825 - 25×tier)
decoyMin = 600
decoyMax = max(1,100, 2,000 - 170×tier)
```

The live-decoy cap cannot exceed `cellCount - 1`. A full board retries a decoy
opportunity after 150 ms. Random intervals, cells, colors, and lifetimes use an
injected generator; seeded randomness is for deterministic tests, not a server
schedule.

Before 10 seconds the initial player color stays fixed. A correct tap at/after 10
seconds chooses another color excluding all visible decoy colors; if none remains,
keep the current color. Mistakes do not change color.

## Decoys

- Decoys never use the player's current color, last 1–3 seconds, and reserve their
  cells until expiry.
- Correct hits do not clear them. Multiple live decoys begin only at 70 seconds.
- Natural expiry awards one 550-point, unmultiplied dodge.
- A mistake, restart, abandonment, or run end clears live decoys without credit.
- A just-expired decoy cell cannot host the immediately following target.
- Ignored opportunities are proof events; Zen has no decoys.

## Score, rating, and streak

Use the same rounded reaction milliseconds for display, rating, proof, and score:

```text
remaining = clamp(1 - reactionMs / responseWindowMs, 0...1)
base = round(100 + 900 × remaining²)
tapAward = base × multiplierBeforeThisTap
```

| Rating | Rounded reaction | Streak steps |
| --- | ---: | ---: |
| Godlike | `<250 ms` | 2 |
| Perfect | `<350 ms` | 1 |
| Great | `<450 ms` | 0 |
| Good | `>=450 ms` | 0 |

Five steps unlock the next multiplier for subsequent taps. Overflow carries;
Great/Good preserve progress; 5× is the cap; every mistake resets to 1×. Dodges
are neutral and never multiplied. Input exactly at the deadline is late.

## Arcade proof and ranking

Arcade uses build `20260729-1`, `reaction-proof-v3`, proof version 2. Integer tuples:

| Opcode | Tuple |
| ---: | --- |
| 0 | target `[0, at, cell, playerColor]` |
| 1 | hit `[1, inputAt, handledAt, cell, resultingPlayerColor]` |
| 2 | miss `[2, inputAt, handledAt, reason, cell]` |
| 3 | decoy `[3, at, id, cell, decoyColor, lifetimeMs]` |
| 4 | natural expiry `[4, at, id...]` |
| 5 | finish `[5, logicalAt, handledAt]` |
| 6 | ignored decoy opportunity `[6, at]` |

Miss reasons are 0 empty, 1 wrong, 2 late. PHP derives score, ratings, multipliers,
dodges, duration, completion, achievements, and coin time. A repeated run UUID is
idempotent. `verified` is accepted only for the exact issued run ID; `review` and
`quarantined` are persisted but withheld.

Every accepted Arcade run is an immutable row. Public reads show the top five;
authenticated context adds the player's best and neighbors. Order is score,
duration, hits, creation time, then stable result ID. Zen rows are historical and
read-only.

## Historical Multiplayer v1

Uploaded build 24 uses the old fixed 4×4 GameKit peer coordinator and
`multiplayer-own-color-v1`, protocol/proof 1. That implementation's rotating
targets, sealed input frontiers and unanimous transcript settlement are not v2
rules. Historical clean results retain `peer_consistent_v1`; they are neither
server-authoritative nor retrospectively upgraded. Old schedule/transcript details
are recoverable from Git history. No historical PHP data is deleted by the rewrite.

## Presentation, rewards, and cosmetics

- Arcade/Zen start reaction timing on the first visible render frame and use the
  original compatible touch timestamp. One transition wins touch/expiry.
- Arcade reveals **Your Color** only after engine start; Zen intentionally shows
  **Any**. Themes/glyphs never change hit geometry.
- One coin accrues per cumulative protocol-verified Arcade minute, with sub-minute
  carry. Achievement claims are idempotent ledger credits. StoreKit coins do not
  count toward gameplay-coin achievements.
- Default/Disco are free; Light 50 coins; Pixel 100. Pets: Foka 10, Kesha 20,
  Tauta 50, Misha 100, Pancake 500. Server response owns catalog, purchase,
  selection, special pets, and balance.
- Sound FX and Music are independent. Disabled categories load nothing; unavailable
  reaction cues are skipped rather than played late. Results are silent.
