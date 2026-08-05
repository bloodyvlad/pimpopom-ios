# iOS task — FAST Multiplayer response and pacing

Status: approved design, not implemented. Owner priority: make Multiplayer feel
immediate. PHP is not edited by this iOS task.

## Outcome

Make a local Multiplayer tap visibly respond within one display frame while
preserving deterministic peer reconciliation and PHP replay. Under normal network
conditions canonical state should follow within 150 ms, not the current 250–300+
ms floor. Then give every active player an independent target cadence so four-player
play does not feel four times slower.

This uses the standard responsive-network-game pattern: acknowledge safe local
intent immediately, keep authoritative/canonical state separate, and reconcile
when the shared result arrives. It does not claim knowledge of Slither.io's private
implementation.

## Why build 20 feels slow

Single-player resolves the original `UITouch.timestamp` synchronously and applies
audio/state/scene feedback in the same call path. Multiplayer instead:

1. sends every GameKit packet with reliable delivery;
2. advances the coordinator on an approximately 33 ms main-actor loop;
3. holds input behind a fixed 250 ms reorder watermark;
4. resolves/removes the active target and updates rating, score, life, and sound
   only after canonical commit, although scheduled future targets can appear at
   their planned time;
5. makes a non-coordinator wait for outbound transit plus canonical return;
6. measures from planned target time rather than its later first-render frame; and
7. rotates one global target among 2–4 seats.

Expected current coordinator feedback floor is about 250–283 ms. A remote player
also pays network/frame delay and reliable head-of-line blocking. PHP sees only
lobby/start/final settlement traffic, so tap verification on PHP is not the live
latency source.

Current correctness defects amplify the feeling:

- no local pending-tap latch leaves the old target visibly tappable;
- a rapid second tap can become another miss or unresolved evidence;
- ignored recovery/expired/eliminated/finished inputs create no canonical tuple;
- evidence identity omits `inputSequence`, so same-millisecond duplicates collide;
- final submission refuses any evidence that remains unexplained.

## Product contract

- A locally eligible tap produces visible acknowledgement no later than the next
  display frame.
- Prediction is presentation only. It never changes canonical score, lives, streak,
  transcript, shared accepted-hit tone order, or settlement.
- One activation accepts at most one local input until canonical disposition.
- Every witnessed input has stable `InputID = (seat, inputSequence)` and exactly one
  disposition: committed to an event sequence or ignored for a versioned reason.
- An input contacted before its target deadline is not converted into an expiry
  merely because the fast copy was lost and reliable evidence arrived later. Keep
  all later canonical events behind sealed per-seat input frontiers until that
  earlier evidence is complete or the match cancels.
- Reconciliation clears the overlay on agreement and restores/corrects it without
  a second penalty on disagreement.
- No target, tap, HUD, tone, or pet event travels through PHP.
- Network quality outside the supported budget pauses/cancels honestly; it does not
  silently increase reaction difficulty or fabricate proof.

## Architecture

```text
UITouch contact
   ├─ local prediction overlay → next display frame
   ├─ fastInput + cumulative seal (.unreliable) ─┐
   └─ evidence + cumulative seal (.reliable) ────┼→ sealed publish frontier
                                                 │             ↓
                    reliable canonical resolution ← all peers reconcile
```

Keep two state domains:

- **Predicted presentation:** local input latch, pressed/consumed target, neutral
  tap pressure, pending marker, and timing signposts.
- **Canonical state:** reducer, score, lives, streak, target ownership, transcript,
  shared accepted-hit tones, results, and settlement.

Do not mutate the reducer to make prediction look authoritative.

### Transport lanes

The current receiver has one monotonic per-sender packet sequence. Mixing reliable
and unreliable delivery under it is unsafe: unreliable `N+1` can arrive first and
cause later reliable `N` to be discarded. Introduce explicit lanes with independent
per-sender sequences:

| Lane | GameKit mode | Contents |
| --- | --- | --- |
| `fastInput` | `.unreliable` | Small input intent plus repeated cumulative input seal |
| `evidence` | `.reliable` | Same original evidence, cumulative seal, journal/resend state |
| `canonical` | `.reliable` | Events and input dispositions |
| `control` | `.reliable` | Wire capabilities, roster, clock, plans, snapshots, lifecycle |

Whichever copy of an InputID arrives first may queue it; process it once. Identical
duplicates deduplicate. Conflicting content for one InputID is a consistency error.
Retain a bounded sender journal and resend reliable evidence until cumulative
per-peer acknowledgement or terminal cancellation. Canonical gaps still use
snapshots; a coordinator cannot invent missing sender evidence.

Apple documents unreliable mode for small latency-sensitive packets and reliable
mode for guaranteed ordered data: [Exchanging data between players in real-time games](https://developer.apple.com/documentation/gamekit/exchanging-data-between-players-in-real-time-games)
and [`GKMatch.SendDataMode.unreliable`](https://developer.apple.com/documentation/gamekit/gkmatch/senddatamode/unreliable).

### Live-wire compatibility

Build 20 decodes a closed GameKit payload enum, while old and new clients can share
the same PHP build/protocol tuple. PHP transcript compatibility therefore does not
make a new live packet safe.

- Extend the existing `hello` body with optional `liveWireVersion` and exact
  capability identifiers. An old decoder must continue to accept that hello.
- Send only old-compatible hello/control traffic until every seat reports the same
  required capabilities. Block the new client's Ready action, roster confirmation,
  and start until the set is unanimous.
- If any hello omits or mismatches the required version/capabilities, show **Update
  Required**, leave/cancel before gameplay, and never send an unknown payload kind
  to that peer.
- If this fail-before-start guarantee cannot be proven entirely in the live hello,
  use a new backend-allowlisted client build tuple before enabling the feature.
- Test mixed versions with both old and new clients in creator and joiner roles.

The PHP transcript may remain v1 for the safe milestone, but live-wire compatibility
is explicit and independently versioned.

### Canonical finality and coordinator policy

- Measure pre-start RTT, jitter, and loss for every peer.
- Negotiate a maximum input-frontier staleness budget from the worst participant,
  clamp it to 40–100 ms, and freeze it before gameplay. This is a health/recovery
  threshold, not a deliberate sleep on the clean path.
- Serialize touch capture and seal generation per seat. At least once per display
  frame, send a monotonic cumulative `inputSeal(throughInputAt,
  highestInputSequence)` after enqueuing every local contact through that time.
  Repeat seals on the fast lane and checkpoint them on the reliable evidence lane.
- A seat's effective frontier advances only when the coordinator has its seal and
  every InputID through the declared sequence. A later new sequence may never claim
  a contact time at or before an already effective seal.
- Define the canonical publish watermark as the minimum effective sealed time over
  all live seats. Queue inputs immediately, but advance the reducer and publish
  inputs, expiries, decoys, or any later canonical event only through that watermark.
  This preserves `(inputAt, seat, inputSequence)` order without rollback.
- Also freeze an evidence-recovery budget derived from the worst participant:
  `clamp(2 × p95 RTT + 2 × p95 jitter, 120...250 ms)`. A supported network profile
  must deliver the reliable evidence copy inside that bound under its declared
  loss/retry schedule.
- Start recovery when a seal declares a missing sequence or a frontier exceeds its
  staleness budget. Do not publish beyond the last complete global watermark. If
  the gap does not close inside the recovery budget, pause/cancel without settlement;
  never roll back a published event or unlock the same activation for a second tap.
- Process complete frontier/input arrivals event-first rather than waiting for the
  old 33 ms polling interval. The normal-profile design budget is one 60 Hz seal
  frame (16.7 ms) + one measured RTT (60 ms) + two application frames (33.4 ms) +
  jitter allowance (15 ms) = about 125 ms, leaving roughly 25 ms processing margin
  below the 150 ms p95 gate. Measure the complete path and refuse FAST ranked start
  when negotiation cannot satisfy that target.
- Use GameKit's best-host selection signal, agree unanimously on the same candidate,
  and retain lexical `gamePlayerID` only as deterministic fallback/tie-break.
- Do not migrate coordinator authority mid-match in this task.

## Milestone 0 — Instrument the baseline

Add release-disabled/non-PII signposts for:

- touch contact;
- target first visible frame;
- first local acknowledgement frame;
- fast and reliable coordinator receipt;
- per-seat input seal, effective global publish watermark, and recovery gap;
- canonical commit and application;
- disposition receipt;
- frontier stall, evidence recovery, and compatibility cancellation;
- accepted audio start.

Do not use current `handledAt` as measured receipt latency; it is clamped by the
watermark. Produce percentile reports by seat, coordinator role, refresh rate, RTT,
jitter, loss, and match size. Never record nicknames, provider/player/profile,
match or settlement IDs, raw transcripts/proofs, or tokens. Use only ephemeral
per-run sample keys to join signpost events; discard them after aggregation.

## Milestone 1 — Immediate local feel, current PHP proof unchanged

1. Add the live-wire capability/version hello and fail-before-start behavior. Do
   not send a new payload kind until every seat confirms the exact capability set.
2. Add one in-flight local input latch keyed by activation/target and InputID.
3. On an eligible owned target, hide/latch or render a consumed/pressed state within
   one frame and block repeat input until disposition.
4. On a wrong/non-owned cell, show immediate neutral pressure feedback without
   hiding another player's target or changing a life.
5. Keep score, life, streak, rating, transcript, and accepted-hit tone canonical.
6. Drive due target visibility and prediction through a display-link-backed frame
   scheduler. Publish the complete live presentation only when state changes; do
   not rebuild every cell/player at 120 Hz.
7. Add a reliable, live-only `inputResolution` packet for every witnessed InputID.
   It names the committed event sequence or a versioned ignored reason, is consumed
   by every peer, and is excluded from the v1 PHP transcript.
8. Evidence and resolution can arrive in either order and can originate from
   different peers. Buffer both by InputID; presentation may reconcile on resolution,
   but peer-consistency bookkeeping consumes the pair only when both are present.
9. Clear the latch/evidence on that resolution or on a snapshot/phase transition
   that proves the activation ended. A watchdog requests a snapshot and enters a
   noninteractive syncing state; it never times out by reopening the same target.
   Cancel without settlement if resolution cannot be established.
10. Reconcile canonical agreement silently. On disagreement, restore/correct the
   overlay once and never charge a second life for the predicted state.

This milestone delivers the largest perceived improvement and blocks burst-tap
duplicates without changing PHP transcript grammar. It may release independently
only after the live-wire handshake and mixed-version gates pass.

## Milestone 2 — Fast GameKit input and canonical response

1. Implement the four independent transport lanes and lane-specific sequences.
2. Send each intent on unreliable fast and reliable evidence lanes under one ID.
3. Move live-only input resolutions onto the canonical lane and make their resend,
   acknowledgement, deduplication, and reconnect behavior deterministic. Keep the
   v1 form out of the PHP transcript. It remains either `committed(eventSequence)`
   or an ignored reason such as duplicate, recovery, already-resolved,
   pre-presentation, stale target, eliminated, or finished.
4. Extend peer consistency to include `inputSequence`; consume evidence only once.
5. Add bounded evidence journal, cumulative acknowledgements, resend, reconnect,
   snapshot, and terminal cleanup.
6. Emit cumulative per-seat seals, compute only complete effective frontiers, and
   advance canonical state solely through their minimum publish watermark.
7. Negotiate/freeze the 40–100 ms frontier-staleness budget, 120–250 ms evidence
   recovery budget, and best coordinator before start.
8. Exercise an earlier lost fast input plus a later fast arrival and delayed reliable
   recovery. The later event must not publish first or require rollback.
9. Buffer canonical application when its required sender evidence/disposition is
   missing, while leaving the local prediction responsive.

Milestone 2 may preserve the v1 PHP tuple grammar only if compatibility tests prove
the changed client build/reorder/disposition metadata is accepted without changing
server replay meaning. Otherwise it waits for the versioned handoff below.

## Milestone 3 — Multiplayer v2: first-render fairness and per-seat cadence

The following are incompatible with the current single-target v1 state/proof and
must not ship as an iOS-only reinterpretation:

- scoring from the owner device's actual first visible frame rather than planned
  shared `at`;
- simultaneous/concurrent per-seat targets and deadlines;
- transcript-visible input dispositions;
- a coordinator rule different from any server-enforced roster rule.

Create a separate backend task/specification for a new build/ruleset/proof tuple.
It must define:

- per-seat active targets, IDs, cells, presentation anchors, and deadlines;
- deterministic ordering for simultaneous presentations, expiry, input, decoys,
  player-out, and finish;
- bounded owner-device first-visible evidence relative to the advance plan;
- exact InputID/disposition encoding and replay checks;
- how a mistake clears decoys and affects only the tapping seat without erasing
  other seats' valid targets;
- fair per-seat target and dodge cadence under 2, 3, and 4 players;
- unanimous frozen coordinator selection and compatibility rejection;
- size/duration limits, moderation risk, rollout window, and old-client behavior.

Only after PHP v2 replay is staged and contract-tested should iOS enable concurrent
per-seat targets. The intended product result is Arcade-like activity for every
player, not one shared cadence divided by the participant count.

## Likely iOS files

- `Packages/PimPoPomCore/Sources/PimPoPomCore/MultiplayerProtocol.swift`
- `Packages/PimPoPomCore/Sources/PimPoPomCore/MultiplayerCoordinator.swift`
- `Packages/PimPoPomCore/Sources/PimPoPomCore/MultiplayerState.swift`
- `App/Features/MultiplayerController.swift`
- `App/Features/MultiplayerPeerConsistency.swift`
- `App/Features/MultiplayerPresentation.swift`
- `App/Features/MultiplayerViews.swift`
- `App/Services/MultiplayerGameKitTransport.swift`
- `App/Services/MultiplayerModels.swift`

Keep prediction and latency policy in small pure types with focused tests instead
of adding more implicit state to `MultiplayerController`.

## Required automated tests

- Compatibility: old/new hello in both host roles, missing/mismatched capabilities,
  no unknown payload before unanimity, and fail before Ready/roster/start.
- Input latch: one activation, 2–5 rapid contacts, one outbound InputID, no second
  predicted penalty, correct reconcile/restore.
- Transport: independent lane sequences; fast-before-reliable, reliable-before-fast,
  loss, duplication, reorder, delayed reliable evidence, reconnect, and conflict.
- Evidence: every InputID has exactly one disposition; resolution-before-evidence
  and evidence-before-resolution both converge; same-millisecond inputs do not
  collide; ignored paths leave no orphan; terminal submission is exact.
- Finality: monotonic seals, declared sequence gaps, minimum complete frontier,
  earlier fast loss/later fast arrival, reliable recovery, same-time seat/sequence
  ordering, unsupported-quality cancel, and no rollback of published events.
- Coordinator: unanimous best-host choice with deterministic fallback and mismatch
  cancellation.
- Presentation: first-visible/first-ack frame, no 120 Hz full-state publication
  loop, prediction never mutates canonical score/lives/streak/tone order.
- Transcript: byte-identical events across every peer and valid PHP submission.
- v2 core: concurrent targets, simultaneous event order, first-render bounds,
  decoy/mistake semantics, placement, snapshot/replay, 2/3/4-seat fairness.

Automated network matrix for every 2-, 3-, and 4-seat role permutation:

| Profile | RTT | Jitter | Loss | Reorder/duplicate |
| --- | ---: | ---: | ---: | ---: |
| Clean LAN | 10 ms | 2 ms | 0% | 0% |
| Normal | 60 ms | 15 ms | 1% | 1% |
| Edge supported | 100 ms | 25 ms | 3% | 3% |
| Unsupported | above frozen budget | burst | burst | must pause/cancel safely |

Use deterministic virtual clocks and packet scheduling. Do not make CI depend on
live Game Center.

## Acceptance criteria

- Local touch-to-visible acknowledgement p95 `<=33 ms` on 60 Hz and 120 Hz iPhones.
- Under RTT `<=60 ms`, jitter `<=15 ms`, loss `<=1%`, canonical touch-to-application
  p95 `<=150 ms` for coordinator and non-coordinator seats.
- Every in-deadline input whose fast copy is lost but whose reliable evidence
  arrives inside the frozen recovery bound commits with its original contact time
  before any later canonical event.
  Evidence outside the bound produces a reconciliation pause/cancel and no ranked
  settlement, never a silent expiry or fabricated miss.
- Zero duplicate-tap life losses in 2–5-touch bursts against one activation.
- Every InputID has exactly one disposition; zero orphaned evidence at terminal.
- Byte-identical transcripts on all peers.
- Mixed live-wire versions fail before Ready/start and exchange no unknown payload.
- 100% valid transcript submission/settlement across the supported automated
  delay/loss/duplicate/reorder matrix for 2, 3, and 4 seats.
- Prediction never changes canonical score, lives, streak, accepted tone order, or
  final placement.
- No per-tap PHP request and no personal/replayable latency telemetry.
- Concurrent-target v2 gives each living seat its own cadence without exceeding
  protocol pressure/capacity rules.

## Physical acceptance

Run TestFlight matches on distinct real accounts/devices:

- 2, 3, and 4 iPhones, including at least one 60 Hz device and one ProMotion device;
- coordinator and non-coordinator winners;
- simultaneous and rapid taps, wrong/late input, recovery, elimination/spectating;
- foreground/background and one bounded reconnect;
- clean, shaped normal, and edge-supported network conditions;
- terminal transcript submission, settlement, and Multiplayer leaderboard rows;
- audio/haptic order and no stale target, double penalty, stuck pending overlay,
  orphaned evidence, or settlement loop.

Retain only isolated owner-QA evidence: signpost percentiles, exact build/commit,
device/OS/refresh rate, network profile, pseudonymous seat/role, transcript hash,
and settlement outcome. Do not retain nicknames, provider/player/profile IDs,
match or settlement IDs, raw transcripts/proofs, or tokens in latency reports.

## Definition of done

The safe milestone may release independently only after all current v1 compatibility
and device gates pass. First-render scoring/concurrent targets require the separate
PHP v2 implementation and staged replay evidence. Update the current contracts,
tests, build tuple, release record, and rollback plan together; do not merely lower
the constant or switch `send` mode.
