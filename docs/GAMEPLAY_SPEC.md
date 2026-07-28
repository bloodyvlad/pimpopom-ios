# Gameplay parity specification

This specification captures the initial native migration baseline. It intentionally separates game rules from rendering and monetization additions. Native balance changes require a later accepted decision.

## Modes

### Arcade

- Player-facing name: **Arcade**. Compatibility wire/storage identifier may remain `normal`.
- Endless until exactly three mistakes; no hidden time limit.
- Wrong color, decoy, inactive cell, empty board, and an expired correct target are mistakes.
- Each mistake resets the speed multiplier. The first and second life losses begin a 1.5-second recovery before the next round; the third ends Arcade immediately and has no recovery round.
- Authenticated ranked play requires a confirmed nickname and a server-issued attempt before the first target presentation. A signed-out or nickname-unconfirmed session may play local practice that can never be promoted later; failure to bootstrap the PHP session or issue a required ranked ticket blocks Arcade with retry/menu actions.

### Zen

- Endless, local, unranked, no-coin practice.
- No life loss, target deadline, decoy, ranked attempt, proof submission, leaderboard write, achievement, or durable history.
- The current target survives mistakes.
- The quiet interval starts at 1,000 ms and, after each correct reaction, moves halfway toward that reaction: `next = previousDelay + 0.5 × (reactionMs - previousDelay)`. Preserve fractional monotonic milliseconds internally; round only values the UI or a versioned contract explicitly defines as integers.
- **End run** freezes an ephemeral Results view. Restart, menu return, app termination, or reload discards it.

## Board and pressure progression

Grid size and elapsed-time phase are independent until 40 seconds:

```text
if elapsedMs >= 40,000: grid = 4×4
else if correctHits >= 4: grid = 2×2
else: grid = 1×1
```

A slow player therefore stays 1×1 after 10 seconds until the fourth correct tap; a fast player may reach 2×2 before 10 seconds. At 40 seconds, 4×4 is forced regardless of hit count. Decoys require available grid capacity, so a 1×1 phase cannot display one even after decoy scheduling begins.

Frozen baseline configuration:

| Elapsed phase | Response window | Target quiet range | Decoy opportunity range | Configured live-decoy cap |
| --- | ---: | ---: | ---: | ---: |
| 0–10 s warm-up | 1,000 ms | 550–1,100 ms | None | 0 |
| 10–20 s color patience | 1,000 ms | 550–1,000 ms | 2,200–3,600 ms | 1 |
| 20–30 s gentle ramp | Rounded linear 1,000→750 ms | 500–950 ms | 2,000–3,200 ms | 1 |
| 30–40 s rare decoys | 750 ms | 475–900 ms | 600–3,400 ms | 2 |
| 40–50 s 4×4 reset | 1,000 ms | 525–950 ms | 2,200–3,400 ms | 1 |
| 50 s+ challenge | `max(200, 1,000 - 10 × challengeHits)` ms | See formula below | See formula below | `min(6, 2 + tier)` |

At the first target activation at or after 50 seconds, record the current hit count as the challenge baseline. Then:

```text
challengeHits = hits - challengeBaselineHits
tier = floor(challengeHits / 10)
targetQuietMin = max(250, 425 - 15 × tier)
targetQuietMax = max(500, 825 - 25 × tier)
decoyQuietMin = 600
decoyQuietMax = max(1,100, 2,000 - 170 × tier)
```

The effective live-decoy cap is also limited to `cellCount - 1`. An opportunity that cannot create a decoy is recorded as ignored; when the grid has no capacity, the scheduler retries after 150 ms. Random quiet intervals, cells, colors, and lifetimes use an injected generator. Production uses the accepted system random source; deterministic fixtures inject a seeded generator. Introducing a server-provided seed would be a new proof protocol, not migration parity.

The initial player color is random. It stays fixed before 10 seconds. Each correct tap resolved at or after 10 seconds changes it to a different color; mistakes do not change it.

## Decoys

- A decoy never uses the player's current color.
- Decoys activate independently of targets, may overlap, and live for a randomized 450–750 ms.
- Natural expiry awards one dodge worth 550 Arcade points.
- Correct target input, any mistake, restart, background abandonment, or run end clears live decoys without awarding dodges.
- A target activation cannot reuse a cell that displayed a decoy immediately before that activation frame.
- Ignored decoy opportunities are explicit proof events so a client cannot omit required pressure invisibly.
- Zen never schedules or displays a decoy.

## Reaction score and ratings

Use the same rounded reaction milliseconds for player display, rating classification, proof replay, and scoring.

For a correct target within its response window:

```text
ratio = clamp(reactionMs / responseWindowMs, 0...1)
basePoints = round(100 + 900 × (1 - ratio)²)
tapAward = basePoints × currentMultiplier
```

Ratings:

- under 250 ms: **Godlike**
- under 350 ms: **Perfect**
- under 450 ms: **Great**
- 450 ms or slower: **Good**

Input at the exact response deadline is expired/late, not correct.

## Speed streak and multiplier

- Five steps unlock the next multiplier for subsequent correct taps, up to 5×.
- Godlike adds two steps; Perfect adds one; Great and Good preserve progress without advancing it.
- Overflow carries into the next tier.
- The tap that completes a tier uses the multiplier active before that tap; the new multiplier begins with the next tap.
- Every mistake resets the tier to 1× and clears step progress.
- Dodges are neutral, never multiplied, and do not change the meter.
- Multipliers never retroactively rescale accumulated score and never affect time-based coins.

## Presentation and touch resolution

- Start a target reaction clock on the render frame that first exposes the target.
- Use the original touch-contact timestamp when it is compatible with the presentation clock; document and test the fallback.
- Anchor expiry to the same absolute deadline.
- Ignore input timestamped before presentation.
- Resolve input-versus-expiry once. A queued expiry and touch cannot consume two lives.
- Freeze elapsed time and statistics on the terminal transition.

## Results and leaderboard

- Arcade survival time freezes on the third mistake.
- Results show score first, then elapsed/survival and reaction statistics, including the four-category distribution.
- Every accepted authenticated Arcade run is an immutable result. Public reads show the top five.
- Authenticated profile context shows the player's best result and up to two neighboring ranks; a submission response shows that exact result and its neighbors.
- Top percentage is calculated over ranked result rows, not distinct player profiles.
- Ranking order is score descending, then Arcade duration descending, correct taps descending, earlier creation time, then stable result UUID.
- Historical Zen leaderboard rows may remain read-only. No native Zen run can create one.
- Review, quarantined, and deleted results are not ranked or credited.

## Proof and verification

The native client emits a versioned chronological transition proof rather than authoritative totals. The existing opcode vocabulary to preserve or deliberately version is:

| Code | Meaning |
| ---: | --- |
| 0 | Target presentation |
| 1 | Accepted input/hit transition |
| 2 | Miss/expiry transition |
| 3 | Decoy activation |
| 4 | Natural decoy expiry group |
| 5 | Terminal finish |
| 6 | Ignored decoy opportunity |

The server derives score, ratings, multipliers, dodges, duration, completion, achievements, and eligible coin time. Repeating a run UUID is idempotent; cloning a trace under a different UUID is rejected/quarantined under the server policy. The native contract must not spoof the baseline web build gate and requires its own accepted build/platform compatibility path.

Proof validation is **protocol verification**. Modified clients, automation, computer vision, or omitted physical taps can still produce plausible input; never call it human verified or bot-proof.

## Profile, coins, and achievements

- Anonymous players can play but receive no ranked result, coins, purchases, pets, or achievements.
- One coin is earned per cumulative protocol-verified Arcade minute. Sub-minute verified time carries between eligible runs. Zen earns none.
- High-risk runs receive no rank or coins unless the server later accepts them.

Achievement claims are durable, idempotent server ledger credits. Initial active goals are:

| Stable ID | Goal | Reward |
| --- | --- | ---: |
| `complete_arcade` | Complete Arcade by losing all three lives | 1 coin |
| `godlike_speed` | Make a correct tap under 250 ms | 1 coin |
| `collect_5_coins` | Reach five collected coins from eligible run credits plus claimed achievement rewards | 5 coins |
| `score_over_100k` | Score over 100,000 in one eligible run | 5 coins |
| `buy_a_pet` | Complete the first successful pet purchase | 10 coins |

- Baseline `total_coins_collected` increases for eligible run credits and claimed achievement rewards, so claiming another reward may unlock `collect_5_coins`. Under the proposed paid-value model, StoreKit coin credits do not increment this counter or unlock gameplay achievements.
- **Buy a pet** unlocks only inside the first successful purchase transaction after debit and ownership creation.
- Purchased coin packs introduce real-money provenance and cannot reuse the old earned-time accounting without the rules in `docs/MONETIZATION_AND_PRIVACY.md`.

## Themes and pets

- Before an Arcade run actually starts, the Your Color swatch, name, glyph, fill, and color-specific outline remain empty throughout backend ticket preparation and the one-second Get Ready interval. Reveal only the player color selected by the engine's `start` transition. The presentation must never expose the reset/default color that exists before `start`; Zen keeps its intentional **Any** preview.
- Themes affect presentation and audio identity, never rules, timing, score, hit regions, or target semantics. All live cells and their Theme Shop/Your Color previews use the same canonical glyph bounds; Light glass, Pixel grain/pixel paths, and Disco backlight/scratches remain clipped presentation layers and cannot alter the board geometry.
- Stable baseline themes: Default (`classic`) and Disco are free; Light costs 50 coins; Pixel costs 100 coins.
- Signed-out players may select Default or Disco locally. After authentication, a server-owned available selection takes precedence; paid ownership and selection remain server-authoritative.
- Stable baseline pets: Foka 10, Kesha 20, Tauta 50, Misha 100, Pancake 500.
- Server catalog price, balance, ownership, debit, and selection are authoritative and atomic.
- Selecting an owned item is free. The selected pet can be hidden without losing ownership or selection.
- Non-game pet presentation may include its habitat; gameplay shows only the pet outside the reaction board. Hidden pets appear nowhere.
- Resolve every directional companion from horizontal distance to the visible sprite center through the shared Pet Shop/menu/gameplay resolver; vertical tap distance is irrelevant. A front-facing corridor extends 5% of the active interaction width to either side of center, clamped to a 4–20-point tolerance. The remaining distance through 15% is a persistent half-left/right pose, and farther taps are full left/right. Use screen width in menu/gameplay and the 80-point shop preview width. Directional frames are ordered full-left, half-left, center, half-right, full-right; advance from the currently displayed pose through adjacent frames with 100 ms between intermediate poses and never force a center restart. Use the settle and sleep frames only for the five-second menu idle lifecycle; gameplay companions stay awake. Any tap on the gameplay screen may update facing, including directly on or vertically aligned above/below the pet; only a resolved board-cell hit reaches the engine.
- Pancake uses that shared staged facing contract, one-shot shop interaction, menu sleep/wake lifecycle, and gameplay tap-follow behavior. Render its sprite fifteen native points lower relative to the floor on the menu and Leaderboard only; this correction does not change gameplay or Pet Shop placement. Semantic full-left mirrors the clean full-right frame instead of using the artifacted source. Its butter, syrup, high-contrast eyes, and glowing blue floor remain part of the native replacement contract.
- Native points do not map one-to-one to baseline CSS pixels. Preserve relative visual placement through approved screenshots: habitats stay outside gameplay, Foka/Kesha sit slightly higher in shop/menu contexts, and Misha renders in front of both climber layers.
- The one-time historical Misha nickname entitlement is server migration state. The iOS client consumes ownership returned by the server and never grants a pet from a later nickname change.
- The owner-approved native Pancake replacement is permitted for this internal build and has retained generation/chroma/alpha masters. Public-release ownership and redistribution evidence remains part of the deferred legal review.

## Audio and lifecycle

- Sound FX and Music are independent, default on, remember explicit opt-outs, and have independent volume settings.
- Sound FX owns selected-theme correct-tap tones plus the shared life-loss cue. Music owns the selected-theme melodic menu loop and clean gameplay loop.
- Results and Game Over are silent; menu and gameplay use their matching variants.
- Disabled categories do no context/engine creation, file loading, decoding, caching, or playback work.
- Preload enabled reaction-critical cues, skip unavailable cues instead of playing late, cap overlaps, and stop safely on background/interruption.
- The new PimPoPom launch sting follows the Sound FX preference and never delays first interaction.
