# Current gameplay specification

These are the rules retained by the build-21 candidate. Presentation and economy
cannot silently change them.

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

### Multiplayer

- Exactly 2–4 players; own-color only; build `20260729-1`, ruleset
  `multiplayer-own-color-v1`, protocol/proof version 1.
- Requires an Apple/Google-authenticated profile, confirmed nickname, authenticated
  persistent Game Center player, publishing-enabled link, and fresh proof.
- PHP assigns stable unique seat/color pairs. Only the target owner can hit it;
  another seat's tap is that player's miss and cannot consume the target.
- Each player owns three lives, score, streak, multiplier, reactions, and 1.5-second
  recovery. Eliminated players spectate until everyone is out.
- No coins, coin time, cosmetics, or achievements are awarded.
- Live HUD values are provisional; PHP derives final results from matching complete
  peer transcripts. Clean rows are protocol-verified and peer-consistent, never
  server-authoritative, human-verified, bot-proof, or collusion-proof.

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

## Multiplayer schedule and transcript

The current coordinator rotates one target and decoy ownership across living seats.
Targets are 250–5,000 ms apart. Response windows are 1,000 ms before 20 seconds,
linearly 1,000→750 from 20–30, 750 from 30–40, reset to 1,000 from 40–50, then
decrease 5 ms per owning-player challenge hit to a 200 ms floor. Multiplayer uses
the same scoring/streak rules as Arcade.

The fixed coordinator currently:

1. authors future activation plans;
2. converts touch time to coordinator logical time;
3. sorts queued input by `(inputAt, seat, inputSequence)`;
4. commits only through the minimum complete sealed per-seat input frontier; and
5. broadcasts one canonical event stream and recovery snapshots reliably.

The v1 transcript has contiguous sequence numbers and nondecreasing logical time:

| Event | Tuple |
| --- | --- |
| Target | `[0, seq, at, ownerSeat, targetId, cell, color]` |
| Hit | `[1, seq, inputAt, handledAt, seat, targetId, cell]` |
| Miss | `[2, seq, inputAt, handledAt, seat, reason, cell]` |
| Decoy | `[3, seq, at, ownerSeat, decoyId, cell, color, lifetimeMs]` |
| Expire | `[4, seq, at, decoyId]` |
| Player out | `[5, seq, at, seat]` |
| Finish | `[6, seq, at]` |

The limit is 2,500 events and 15 minutes. All peers must retain the identical
stream plus sender evidence and submit the same manifest hash/transcript. Missing
evidence, sequence recovery, or coordinator loss cancels/withholds rather than
fabricating a result. Placement is score, hits, rounded average reaction, then seat.

Build 21 acknowledges local contact immediately without mutating canonical score,
life, rating, or transcript state. Canonical reconciliation applies those changes
once. Presentation still uses the plan's scheduled `at`, and one target rotates
among all seats; changing either requires separately versioned follow-up work.

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
