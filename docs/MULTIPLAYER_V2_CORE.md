# Multiplayer v2 core contract

Local source implementation, not a deployment or physical-device acceptance.
The separately versioned wire identifies protocol `2` and ruleset
`multiplayer-shared-arcade-v2`. `MP2Engine` is a synchronous `Sendable` value;
one room actor owns it. It imports neither v1 replay nor networking/Apple UI.

## Board and numerical rules

- Two to four stable, distinct seats/colors share the same board. Each seat has
  at most one unresolved target. Independent sampled opportunities and random
  arbitration allow repeated owners. After two seconds overdue, the oldest due
  seat receives the next available target cell. There is no rotating owner rule.
- The board starts 1×1, expands after four total accepted hits to 2×2, and becomes
  4×4 at 40 seconds. Geometry only expands; a later score correction never shrinks
  an already displayed board. A full cell waits without replacing its occupant.
- The engine directly calls `resolveDifficulty`, `ReactionScoring`, and
  `GameConfiguration.standard`. Response windows, rounded quiet sampling,
  personal post-50-second challenge baseline, lives, 1.5-second recovery, ratings,
  subsequent-tap multipliers and score match those shared Arcade functions.
- A quiet delay starts at the accepted original contact or scheduled expiry,
  after personal recovery when applicable. The default reservation lead is
  250 ms. When a hit arrives too late to maintain that delivery headroom, or a
  shared cell remains occupied, the next activation waits. This implementation
  does not promise exact independent Arcade cadence under those conditions.
  Already issued target IDs, cells and response windows never change.
- Targets may arrive in a snapshot before their activation. The renderer reveals
  them at `activateAtMs`, records the first visible frame, and submits the
  original contact timestamp. Local feedback must not wait for a receipt.

## Decoys

All views render each decoy as an explicitly marked neutral trap, including when
optional color glyphs are disabled. Its color belongs to a participant and differs
from the explicit beneficiary's color. Nobody can score it as a target.

Decoys retain Arcade's lifetime, 550-point unmultiplied natural dodge, and
persistence across correct hits. A mistake/disconnect/out clears only that seat's
beneficiary decoys without credit. Another player's target is never consumed by
a wrong-color tap. The global occupancy cap is constrained by the opportunity
owner's Arcade tier and `cellCount - connectedLivingPlayers`, reserving target
capacity. In a full four-player 2×2 game this means no decoys until 4×4. Blocked
decoy opportunities retry after the configured 150 ms. The beneficiary's next
target excludes their last naturally expired decoy cell when another cell exists.

## Admission, correction, and honest limits

The room service authenticates seat membership and fences room epoch/socket
generation before calling the engine. The engine validates target identity, cell,
owner, original presentation/contact ordering and bounds. Presentation may be at
most 750 ms after scheduled activation; receipt may be at most 2,000 ms after
original contact. Reaction is `contact - firstVisible`, independent of receipt.
An exact-deadline reaction is late. These timestamps remain client evidence;
they cannot prove a human-visible frame or prevent a modified client.

Scheduled expiry is provisional. A valid late hit removes that seat's expiry
event and replays its recent outcome journal, restoring lives, streak, challenge
baseline and later score/multiplier awards. A late mistake can invalidate a
subsequent hit or natural dodge that would have occurred during/after its cleared
branch. Exact repeated input IDs return the original receipt, while conflicting
content for an ID is rejected. Nothing requires input seals or peer ACKs.

World changes already exposed to other players are not replayed. A decoy cleared
by a provisional expiry stays void even when that expiry is later corrected;
its cell may already have been reused. Opportunities that were not issued during
provisional recovery are not fabricated retroactively. Targets already issued
keep their identities/windows, while new unissued opportunities use corrected
personal difficulty. These are explicit conservative semantics, not equivalence
to a room that received every packet immediately. Ranking must remain disabled
until staging, clock/presentation plausibility and physical-device gates pass.

The renderer should keep a locally presented own target through its first-visible
response window even if a scheduled-expiry snapshot arrives sooner; its original
ID must never be reassigned to a replacement. The service's provisional snapshot
may briefly show life/score corrections while ordinary late input is admitted.

The per-seat journal checkpoints outcomes older than five seconds. Resolved target
history lasts through its complete admission horizon; input receipts are bounded
at 10,000 per seat. The service separately bounds socket payloads and rates. Late
or invalid input is rejected locally without ending the match for other players.

## Finish and connectivity

With no taps at all, each seat naturally loses three lives and the match finishes.
After the last seat is out, `.finishing` retains 2,750 ms (maximum presentation
offset plus receipt grace) to allow correction. A corrected third expiry can
return to `.playing`. Final gameplay duration freezes at the last actual out;
the receipt grace is excluded. A 15-minute session cap has the same final
admission drain. There are no input-dependent finish seals.

Disconnect voids the affected opportunity and suspends only that seat's schedule.
The service owns its 15-second rejoin policy and explicitly calls reconnect or
eliminateDisconnected. Connected opponents keep playing. The core has no global
disconnect pause or cancellation path and awards no coins or achievements.

## Deterministic evidence

`MultiplayerV2Tests.swift` covers the Codable wire; roster validation; 2/3/4-seat
zero-input finishes; seeded owner repeats, common-grid thresholds and overlapping
targets; Arcade phase/quiet boundaries and the 200 ms floor; exact-deadline input;
presentation and receipt delay; exactly-once/conflicting input IDs; wrong-color
isolation; terminal revival; replay of later multiplier awards; persistent and
exactly-once natural decoy dodges; beneficiary clearing and late-dodge revocation;
and disconnect/reconnect isolation. These are pure package tests, not WSS or
physical-device measurements.
