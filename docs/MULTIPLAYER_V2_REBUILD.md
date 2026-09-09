# Multiplayer v2 — local implementation candidate

Updated 2026-09-09. The owner approved one shared board and a from-scratch live
multiplayer replacement. Local implementation is underway/integrated by the
source task; this is **not deployed, ranked, physically accepted or uploaded**.
Epic: [GPT-147](https://linear.app/gptests/issue/GPT-147/epic-rebuild-pimpopom-multiplayer-immediate-arcade-gameplay).
Issue descriptions are planning history, not proof of current completion.

## Boundary and source

The candidate replaces GameKit live traffic, peer coordination, FAST seals/
frontiers, unanimous transcripts and v1 client mutations. Preserve the
Multiplayer menu, hub capacity/list controls, waiting-room seat order, names,
pets, colors, Ready/Start/Leave positions and themes. Reuse Arcade's `GameScene`,
cell artwork, layout metrics and original-contact bridge. Historical v1
leaderboard reads and unrelated Game Center account/publication functions remain.

Selected implementation:

- Native `URLSessionWebSocketTask` actor; network and JSON work stay off the
  UIKit reaction path.
- Persistent Vapor 4 / SwiftNIO room service in `Server/`, importing the same
  pure Swift `MP2Engine`, protocol DTOs and Arcade rules as iOS.
- Exact tuple `multiplayer-shared-arcade-v2`, protocol `2`; no v1 reinterpretation
  through a higher build ID.
- Separate PHP primary authentication/profile authority and unranked result
  bridge, local commit `78b51ee6768d6f049d44b3b8c2d2073e0aac34e0`.
- One process/replica initially. Room state is memory-resident; terminal delivery
  uses a private filesystem outbox. [Service details](../Server/README.md).

No changes to Arcade/Zen rules, identity ownership, StoreKit, wallet or cosmetics
are implied. V2 entry requires primary sign-in and a confirmed name, not Game
Center. V2 results award no coins/achievements and enter no public ranking,
ranked season or Game Center publication.

## Approved board and implemented rule adaptations

The owner explicitly confirmed **the same board for every player** and accepted
waiting for an own-color opportunity. A 1×1 board has only one cell, so competing
owners necessarily wait; this is not an unresolved individual-board decision.
Numerical Arcade timing/scoring are reused, but independent personal Arcade
cadence is impossible under shared-cell contention and is not promised.

The local engine defines:

- 2–4 fixed seat colors; independent due opportunities with random arbitration
  and repeats, not cyclic turns. At most one unresolved target per seat.
  Different owners may occupy different cells simultaneously.
- Oldest-due priority after two seconds limits scheduling starvation when space
  becomes available; it does not guarantee a free cell by that time. Occupied
  cells are never overwritten. Blocked targets retry after 50 ms plus delivery
  headroom, preserving their due age.
- Shared 1×1 → 2×2 after four **total** valid hits → 4×4 at 40 seconds of match
  time. Grid growth does not rewind after a late correction. Per-seat challenge
  baselines freeze on the first issued target at/after 50 seconds.
- `GameConfiguration.standard`, `resolveDifficulty` and `ReactionScoring`
  supply numerical response, quiet-delay, score, rating, streak and recovery
  rules. Three lives and 1,500 ms personal recovery; wrong-color/empty/trap taps
  penalize only that seat and never consume a peer's target.
- Explicitly marked decoys use another participant's color, including when
  optional color glyphs are off. No seat can score one as a target. One named
  beneficiary earns the unmultiplied 550-point natural dodge; it is not paid to
  every spectator. Lifetime is the shared Arcade 1–3 seconds.
- Decoys persist on correct hits. Personal mistakes/disconnection clear that
  seat's decoys without credit. One global Arcade cap reserves capacity for
  connected living targets; it is not multiplied by player count. Consequently,
  a full 2×2 with four living players may have no decoy capacity.
- A just-expired decoy cell is avoided for the beneficiary's next target when
  another free cell exists; shared-board exhaustion permits a free-cell fallback.
- All-out or 900,000 ms ends play after the final admission horizon. An eliminated
  player spectates. Leave ends only that seat; disconnect allows a 15-second
  return while the remaining players continue.

Early Arcade target quiet ranges are 550–1,100, 550–1,000, 500–950, 475–900 and
525–950 ms over the successive 0/10/20/30/40-second phases. Post-50-second personal
challenge rules retain the 200 ms response floor. These are shared numeric
inputs, **not a guarantee of wall-clock inter-target spacing**: receipt latency,
delivery lead, reserved visible windows and occupied cells can lengthen it.
Current lead defaults to 250 ms and is bounded by 750 ms; adaptive/pre-issued
conditional scheduling from the original proposal is not proven implemented.
Synthetic UI fixtures with widened response windows are layout evidence only.

## Authority, presentation and recovery

Room membership, revisioned Ready and Start have one authority: the socket service.
The creator starts a full 2/3/4-seat room only after everyone is connected and
confirmed Ready. Ready carries a monotonic intent ID and roster revision; duplicate
Start returns the same countdown. Roster changes invalidate a countdown. A match
starts and advances with zero input activity; no peer input seals or ACK barrier
are required.

The app projects immediate local Ready and touch feedback, then reconciles input
receipts and snapshots. It records first-visible monotonic time and original
touch contact, not network arrival as reaction time. Pending predictions must not
replay sound/haptics/fly-outs. Stale socket/match generations cannot mutate new
state. Server code checks identity, ownership, timing and bounded idempotency;
clients never submit score/life claims.

The engine accepts at most two seconds of receipt lateness and up to 750 ms
presentation allowance. This does not extend the 200–1,000 ms reaction window:
a contact exactly at its deadline is late. Per-seat causal replay can correct a
provisional expiry once, including recovery/streak/elimination effects; the final
admission horizon is 2,750 ms. Target cells remain reserved through the admitted
visible window. First-visible timestamps are client evidence, not proof of a
human-visible frame; adversarial timing and complex causal cases remain acceptance
work, and ranking stays disabled.

The room service serializes mutations without awaiting network or disk. It requests
60 Hz advancement and 10 Hz periodic snapshots, with immediate critical changes.
Bounded per-socket readers/writers and coalescing keep slow peers from blocking
others. These rates are settings, not measured latency or room-capacity results.

Reconnect authenticates a fresh PHP ticket before rotating a player/room-bound
resume credential and generation. A missing seat loses only its own opportunities.
Service/PHP authentication failure must not retain stale authenticated authority.
A process restart loses active rooms; do not manufacture wins or completed results
from that infrastructure interruption.

## PHP bridge and terminal result isolation

The local PHP bridge is disabled by default until private
`SPEEDYTAPPER_REALTIME_URL` and `SPEEDYTAPPER_MULTIPLAYER_SERVICE_SECRET` are
configured. Additive migration 023 creates separate v2 tables. Nothing here
establishes that a live schema has been migrated.

- `POST /api/mobile/v2/multiplayer/tickets`: existing cookie/CSRF/same-origin
  policy, primary profile and confirmed nickname. JSON includes protocol/ruleset;
  response is `{ticket, expiresAt, realtimeURL}`. Ticket is random, digest-stored,
  single-use, valid at most 60 seconds and bound to player/session/protocol.
- Service Bearer authentication only, no cookie/CSRF:
  `POST /api/internal/multiplayer/v2/tickets/redeem` and
  `POST /api/internal/multiplayer/v2/sessions/validate`.
  Identity response includes `playerID, name, petID, sessionBinding, expiresAt,
  protocolVersion, ruleset`; timestamps are Unix seconds. Binding expires within
  an hour, bounded by its source session. Validate every 15 seconds and on return;
  logout/rotation/deletion revoke access through this bounded check, not instant push.
- Service-only `POST /api/internal/multiplayer/v2/results` takes bounded immutable
  match/seat aggregates with `rankingEligible:false`. Same normalized payload
  retries idempotently; different content for the same match ID returns 409.
  PHP acknowledges `state:stored_unranked` and matching match ID before archive.
  PHP does **not** independently replay live inputs or verify human play.
- No PHP lobby directory competes with the socket directory. No v1 rank tables,
  progression, rewards, moderation state or publication outboxes receive v2 writes.
  Account deletion removes the shared alpha aggregate; delayed delivery cannot
  recreate a deleted player.

The terminal outbox stores bounded atomic JSON files without names, pets, tickets
or session bindings and retries off the touch/room mutation path. Mount persistent
storage; an ordinary container filesystem is insufficient. Delivery disabled or
PHP unavailable leaves pending evidence locally, not proof of server storage.
Drain, backup/retention, disk-full response and recovery require operational tests.

## Hosting and release gates

The owner will choose hosting separately. [Official-source shortlist and prices](MULTIPLAYER_V2_HOSTING.md)
compare Render, Railway, Fly.io and DigitalOcean, with current Vercel corrections.
No hosting purchase, deployment, public endpoint or new TestFlight upload occurred
in this local implementation task. Existing PHP/Apache hosting is not proof of a
persistent Swift process/volume capability.

Before a release claim:

1. Record the exact integrated commit and full iOS, shared-core, Linux/service,
   PHP and disposable MariaDB checks; see [CURRENT_VERSION](CURRENT_VERSION.md).
2. Exercise authenticated WSS plus real PHP tickets/revocation and idempotent
   outbox delivery across outages, restarts and account deletion.
3. Test 2/3/4 independent clients with zero taps before Start, natural completion,
   duplicate messages, late input, roster changes, clock changes, background,
   reconnect and bounded slow-peer queues.
4. Measure memory, capacity, CPU, egress and loss/jitter behavior on the selected
   host. For RTT ≤150 ms/jitter ≤50 ms, desired local contact-to-feedback p95 is
   within one display frame; peer Ready ≤250 ms, confirmation ≤300 ms, and
   convergence within two seconds of a usable connection are targets, not results.
5. Validate named physical 2/3/4-iPhone Wi-Fi/cellular and 60/120 Hz cases, compact
   screens, four themes, glyphs-off traps, VoiceOver and lifecycle. Display-link/
   Simulator timestamps are not glass-to-glass physical timing.
6. Verify TLS, secrets, supervision, drain, bounded persistence, backups,
   monitoring and rollback. Select a new release identity only when authorized;
   current configuration remains `1.02 (24)`.

## Historical audit baseline — not current line references

The September 8 research audited iOS
`df16cb8ef43adf3752023d12329384c2e0a08eaa` and PHP
`ec1b5a76068319b16b28bcad456d6ccb79628ad8`. Paths/lines below refer **only to those
commits**, including files removed by v2; they are not navigation into today's code.

| Baseline finding | Historical evidence |
| --- | --- |
| Zero-tap seal/progress failures were possible | `MultiplayerController.swift:1995,2214,2350`; `MultiplayerFastPolicy.swift:90` |
| Multiple startup failures shared generic UI copy | Controller `1222,1921,2695,3708`; DEBUG-only logging at `235` |
| Fixed 4×4, rotating single-target rules differed from Arcade | `MultiplayerProtocol.swift:11`, `MultiplayerState.swift:380`, `MultiplayerCoordinator.swift:216` |
| First-visible versus scheduled reaction clocks differed | `GameScene.swift:87,103`; controller `2014,2988` |
| PHP v1 was peer settlement, not live authority | `MultiplayerMatchService.php:348,435` |

The reported zero-score screenshot was consistent with several paths, not a
reproduced incident diagnosis. Historical iPhone 17/iOS 26.5 Simulator captures:
[menu](evidence/2026-09-08-multiplayer-audit/menu.jpg),
[hub](evidence/2026-09-08-multiplayer-audit/hub.jpg),
[waiting room](evidence/2026-09-08-multiplayer-audit/waiting.jpg),
[v1 gameplay](evidence/2026-09-08-multiplayer-audit/multiplayer.jpg),
[Arcade](evidence/2026-09-08-multiplayer-audit/arcade.jpg).
They are synthetic Classic-theme fixtures, not v2 or real multi-device evidence.

That audit's `Scripts/check.sh` exit 0, 73 core tests and
`/tmp/pimpopom-v2-audit-check-20260908.log` establish only its v1 baseline.
The original proposal, alternative-stack analysis and GPT-148 through GPT-159
planning details remain in Git/issue history; their old “Backlog” labels do not
describe current implementation or prove acceptance.
