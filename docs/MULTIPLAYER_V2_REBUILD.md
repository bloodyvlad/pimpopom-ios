# Multiplayer v2 replacement — implementation brief

Date: 2026-09-08. Status: researched replacement design, **not implemented or
deployed**. This document does not redefine the shipped v1 API or claim that the
reported TestFlight failure has been reproduced. Implementation epic:
[GPT-147](https://linear.app/gptests/issue/GPT-147/epic-rebuild-pimpopom-multiplayer-immediate-arcade-gameplay).

## Outcome and boundary

Replace the peer coordinator, FAST input seals/frontiers, evidence lanes,
canonical peer transcript and unanimous settlement. Preserve the Multiplayer
button, game-list layout, waiting-room design, themes, names, pets and color tiles.
Reuse Arcade's rules and reaction/rendering primitives, not v1 synchronization.
Do not rewrite identity, Arcade, Zen, StoreKit, economy or Game Center publication.

Selected architecture: native `URLSessionWebSocketTask` over WSS/443, with one
persistent **Vapor 4 / SwiftNIO authoritative room service**. Import a versioned,
Linux-tested pure Swift rules package shared with iOS. PHP/MariaDB retains primary
authentication, profile data, durable results, moderation and publication.
This is a project-fit recommendation, not a measured claim of lowest latency.

The new path requires its own protocol/ruleset and endpoint. A higher build ID
must not reinterpret v1. Build v2 beside the old path behind an explicit feature
selector, then remove v1 client code at validated cutover. Retain historical PHP
results and migration history; removing implementation does not mean deleting data.

## What the audit established

Source: iOS `df16cb8ef43adf3752023d12329384c2e0a08eaa`; PHP
`ec1b5a76068319b16b28bcad456d6ccb79628ad8`. Both checkouts were initially clean.

| Finding | Evidence |
| --- | --- |
| Failure can happen with zero taps | `MultiplayerController.swift:1995,2214,2350`: display-frame processing emits seals and checks progress even without input. `MultiplayerFastPolicy.swift:90`: all active seats are required and the minimum seal governs progress. |
| Other startup faults look like tap faults | Controller lines 1222, 1921, 2695 cover roster change, initial plan delivery and reliable-control timeouts. Line 3708 replaces every fatal reason with the same synchronization message; original logging at line 235 is DEBUG-only. |
| Current rules are not Arcade with extra players | `MultiplayerProtocol.swift:11` fixes 16 cells; `MultiplayerState.swift:380` enforces rotating owners and one target; `MultiplayerCoordinator.swift:216` chooses the next living seat. |
| Current reaction clocks differ | Arcade `GameScene.swift:87` records first-visible-frame uptime and line 103 original touch time. MP controller lines 2014/2988 use scheduled plan time; first-visible time is telemetry, not scoring authority. |
| Existing PHP cannot referee live play | `MultiplayerMatchService.php:348` requires GameKit roster/coordinator agreement; line 435 collects peer submissions. No live tap loop exists. |

The supplied zero-score screenshot is consistent with these paths, but does not
identify which fired. Exact installed build plus correlated release-safe logs
would be needed for a specific incident diagnosis. Another timing-grace patch
cannot provide the requested random, concurrent, progressive-board gameplay.

## Screen comparison and preservation

The current app was built and run on the iPhone 17 / iOS 26.5 Simulator. Captures
are synthetic Classic-theme fixtures, not a real multi-device match:

- [Menu](evidence/2026-09-08-multiplayer-audit/menu.jpg).
- [Hub, signed-out state](evidence/2026-09-08-multiplayer-audit/hub.jpg).
- [Four-player waiting room](evidence/2026-09-08-multiplayer-audit/waiting.jpg).
- [Current four-player gameplay](evidence/2026-09-08-multiplayer-audit/multiplayer.jpg).
- [Arcade gameplay](evidence/2026-09-08-multiplayer-audit/arcade.jpg).

Keep hub capacity 2/3/4, Create/Join/Refresh/Leaderboard, list cards, waiting-room
seat order, pet/name/color/Ready rows and Start/Leave positions. Inspect populated
list rows in `MultiplayerViews.swift:330`; the captured hub is not that state.
Change their data source, not their visual identity. Remove the Game Center
multiplayer prerequisite in v2 while retaining Apple/Google sign-in and confirmed
public names; preserve Game Center's unrelated link and leaderboard functions.

Arcade has a utility header, points/top-score, Your Color, elapsed/lives, square
board, response progress, speed/streak bar and pet. MP currently compresses the
HUD, omits elapsed/top-score and uses a fixed 4x4 SwiftUI board. V2 should share
Arcade's layout, SpriteKit cell rendering and original-contact input bridge.
Replace Arcade's top-score field with local competitive rank/leader gap; retain
elapsed time and local lives. Add a compact, stable-seat strip for all players:
color/glyph, name, score, lives/out, multiplier and leader crown. Local seat stays
highlighted. Do not reorder the strip on each score change or cover the board
with opponent fly-outs. Opponent reactions may update later.

Reuse `GameBoardLayout`, `GameCellPreview`/cell artwork, `GameHUDMetrics`,
`GameplayLayoutMetrics`, `GameplaySpeedBarView`, `GameplayHitFeedbackLayer`,
`ThemePalette` and existing pet assets. Factor a common gameplay shell, with
mode-specific controls (Leave for MP, not an independent Restart).
Require 2/3/4-player, compact-screen, four-theme and accessibility snapshots.
Do not reduce touch area to fit more competitive text.

## Gameplay contract to freeze before engine implementation

User requirements: 2–4 stable player colors, random ownership including repeats,
no turns, overlapping targets where space permits, other-player-color decoys,
1x1 → 2x2 → 4x4, Arcade timing/scoring and immediate feedback.

Working interpretation is one shared board; a nonblocking clarification was sent.
It is impossible to put two differently colored targets simultaneously in one
cell. A shared 1x1 must queue target appearances. Exact independent per-player
Arcade cadence is therefore impossible during shared-cell contention. If the
owner means exact personal cadence without this exception, use individual boards
instead. Do not conceal this distinction in the implementation.

Proposed shared-board rules, to freeze in the first implementation task:

- Use independent per-seat target opportunities from the Arcade delay ranges;
  at most one unresolved own target per seat. Randomize initial offsets and
  choose among due eligible seats without a cyclic owner rule. Repeated owners
  are valid. On 2x2/4x4, different free cells may activate in the same frame.
- Never overwrite a live target/decoy or shorten its response window to make room.
  A blocked opportunity waits for a free cell, with bounded queue/fairness policy;
  no artificial globally enforced gap between different seats' targets.
- Proposed common grid: 2x2 after four total valid hits, 4x4 at 40 seconds of
  shared active match time. Four total hits is a multiplayer adaptation, not
  four personal hits. Freeze it explicitly; do not silently choose an average,
  fastest or slowest participant. Difficulty windows and post-50-second tiers
  remain per-seat using that seat's challenge baseline.
- Own-color targets are hittable only by their owner; other colors are distractors
  for the local player, not a reason to wait for a turn. A wrong-color tap costs
  only the tapping player's life and cannot consume another player's target.
- A same-looking own-color trap is ambiguous: do not introduce one. A decoy in
  another player's color on a shared board needs either an explicit trap marker
  visible to its color owner or per-view semantics. Proposed marked neutral
  decoys use participant colors, cannot be scored as targets by any seat, and
  retain Arcade lifetime/550-point natural-dodge rules with an explicit beneficiary
  seat. Assign decoy opportunities per seat; no multiplied dodge reward per peer.
  Decoy color must differ from its beneficiary's color. Bound global occupancy
  and reserve target capacity; never multiply Arcade's cap by four without a
  physical cell limit. Define clear-on-mistake/recovery/elimination, persist-on-hit
  and just-expired-cell exclusion explicitly. Finalize marker/beneficiary and
  cap arbitration in the rules task, including glyphs-off.
- Three lives per seat, 1,500ms personal mistake recovery, existing score/rating/
  streak formulas; other players continue. Eliminated players spectate. End when
  all are out, or an explicit bounded session limit is reached. No MP coins or
  achievements. Abandonment is not a global protocol error.

Do not copy numerical timing into the server. Share `GameConfiguration.standard`,
`resolveDifficulty` and `ReactionScoring` (or extracted pure equivalents). Goldens
must cover 4 hits and 10/20/30/40/50/70-second boundaries, challenge-baseline freeze,
rounded delay sampling, exact-deadline loss, decoy persistence/expiry, recovery and
the 200ms response floor. Early Arcade quiet ranges are 550–1100, 550–1000,
500–950, 475–900 and 525–950ms; post-50s ranges use personal challenge tier.
Existing `--uitesting` fixtures can widen response windows to 5 seconds: they are
layout evidence only, never timing acceptance.

## Realtime design

```text
touch contact → local rule/prediction → next display frame + sound/haptic
                    ↓ asynchronous input queue
             WSS → room authority → own confirmation + opponent snapshots
                         ↓ durable outbox, off the input path
                   PHP immutable result transaction
```

One room owns membership, Ready revisions, scheduled targets, per-seat state,
countdown and lifecycle. Serialize room mutations in one executor/actor; separate
socket I/O and bounded outbound queues. No network/database await inside a room
state mutation, no peer coordinator, no global input seals, no peer ACK barrier,
no client-generated canonical transcript. Begin with a 60Hz deadline scheduler
and event-driven input admission; publish compact competitive state at 10Hz and
critical activation/confirmation events immediately. Rates are benchmark targets,
not achieved measurements. Avoid full-room JSON snapshots on every display frame.

### Ready and start

Update local Ready in the same UI transaction. Send idempotent `setReady(value,
intentSequence, rosterRevision)`, never a toggle. Server broadcasts a revisioned
room snapshot; older snapshots cannot overwrite newer local intent. A reject
rolls back the matching intent with actionable text. Peer updates do not depend
on a PHP polling interval. Atomic Start checks confirmed Ready and current live
membership for 2–4 seats. Duplicate Start returns the same match/countdown.
Roster change invalidates that countdown revision and returns to lobby, not a
zero-score failed match. No match-wide input activity is required to start.

### Presentation and input

Send short target schedules ahead of time (initial adaptive lead 250–750ms based
on measured RTT/jitter). Lead is delivery headroom, not extra quiet time. There is
an essential implementation spike here: Arcade's next quiet delay starts at the
local hit/expiry and can fall to 250ms. Waiting for the server to receive that hit
and send a fresh plan would add network latency. Pre-issued conditional next-target
plans need exclusive cell/time reservations and bounded per-seat prediction. Prove
this under simultaneous hits, especially on 1x1; otherwise choose individual boards
for literal independent Arcade cadence. A buffered schedule alone does not solve
shared-cell contention. Do not implement a hidden ACK barrier as a workaround.
Record first-visible monotonic time per target, then original
touch-contact time. Network arrival time must not become reaction time.

Client inputs carry protocol, room epoch, seat-session generation, input ID,
target ID (or board revision/cell for a miss), first-visible time, contact time
and last received server revision. Never accept a client score/life claim.
Use application ping/echo timestamps for clock-offset estimates; WebSocket ping
alone measures liveness, not clock offset. Keep one receive task and one ordered
bounded writer per connection. Decode off MainActor; send immutable snapshots to
the UI. Cancellation/reconnect generations fence old callbacks.

Server checks membership, target identity/ownership, schema/size/rate bounds,
idempotency and plausibility, then derives score using shared rules. Input for an
old target cannot hit its replacement in the same cell. Retain a short per-target
resolution history so an in-window contact received late can correct a provisional
expiry exactly once without rewinding the whole room. Such a correction can change
recovery, later streak awards, difficulty and elimination: retain and recompute the
affected seat's short causal history, and defer durable finish through the final
admission horizon. Do not merely add points back to a terminal snapshot. Future
targets already exposed to other seats must keep their reserved identity/geometry;
rules must say how conflicting local branches are voided. Prove this in the input
admission spike before promising full 2-second late-input correction.
Per-seat pending predictions
are removed by input-ID acknowledgement; replay remaining predictions over the
latest authoritative snapshot without repeating sound/haptic/fly-outs.

Initial ordinary lateness budget: 2 seconds for receipt/reconciliation, separate
from the 200–1000ms gameplay response window. A 1.5-second reaction is still late;
a 200ms contact packet arriving 1.5 seconds later can still be valid if its
response window exceeds 200ms (at the 200ms floor, that contact is late). This is a
proposed beta policy, to validate under impairments. First-visible timestamps
are client evidence, not proof of an actual human-visible frame. Bound them by
scheduled identity, clock uncertainty, sequence and delivery history. Excessive
uncertainty voids an affected opportunity or makes the run unranked; it must not
abort all players or silently award unvalidated ranked scores.

### Recovery and terminal state

Use heartbeats, bounded exponential backoff with jitter and a short-lived,
player/room/epoch-bound reconnect credential. Reconnect sends the latest snapshot
plus acknowledged input IDs; do not replay all missed frames. Ordinary 1–2s
opponent lag changes a small connection indicator, not board interactivity.
After the schedule buffer is exhausted, show local Reconnecting and void
unpresented opportunities. Backgrounding/disconnect stops new opportunities for
that seat; other seats continue. Proposed 15-second rejoin grace ends only that
seat as disconnected, with defined ranking eligibility and no reconnect advantage.
Service loss is a distinct recoverable infrastructure state, not fabricated wins.

Bound room queues, message sizes, input history and retained results. Slow sockets
receive coalesced newest snapshots; never block healthy seats on their sends.
Keep release-safe structured reason codes (start/roster/socket/schema/expiry),
match/connection correlation IDs and latency histograms, without tokens or raw
identity. Friendly localized UI must not display Swift enum error numbers.

## PHP and operations boundary

- PHP issues short-lived, single-use connection tickets under existing cookie/
  CSRF authentication. Tickets bind internal player, room, protocol, session and
  expiry; store only digests. Redeem through authenticated service-to-service
  introspection. Do not use raw Game Center IDs or expose tickets in URLs/logs.
- Room service owns live Ready/presence/start. PHP game-list API can proxy/cache
  the authoritative room directory; define revision and outage semantics so PHP
  and sockets cannot become competing Ready authorities.
- Revoke live access on logout/deletion; reconnect must revalidate membership.
  No Nakama/device identity, anonymous score writes or new wallet authority.
- Add explicit v2 storage/API and a new result verification method/season. Existing
  v1 lobby, leaderboard and Game Center best-score queries do not universally
  filter protocol. Reusing their tables without full scoping would leak v2 into
  v1. Extend account deletion, moderation and retention for every new table.
- Server journals a completed result and retries delivery from a durable outbox.
  PHP authenticates the service, validates the immutable match/rules/roster and
  finalizes idempotently. Same payload retry returns same result; conflicting
  payload is rejected. Client disconnect or PHP downtime never restarts a match.
  Multiplayer remains unrewarded. Ranking is disabled until validation is proven.
- Need a persistent Linux/container host, WSS upgrade support, TLS, supervision,
  regional latency measurements, graceful room drain, backups, bounded storage,
  health checks and rollback. Existing PHP/Apache hosting metadata proves none
  of these capabilities. Do not assume a socket server fits the current plan.

## Why this stack, and alternatives

[Apple WebSockets](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask)
provides asynchronous RFC6455 text/binary messaging over TCP/TLS without adding an
iOS SDK. [Vapor](https://docs.vapor.codes/advanced/websockets/) supports asynchronous
WebSocket routes, and [Docker deployment](https://docs.vapor.codes/deploy/docker/)
provides a portable deployment route. Use a pinned stable Vapor 4 dependency,
not its alpha successor. Shared Swift rules reduce cross-language drift; validate
Linux compilation before adopting the service skeleton.

| Alternative | Assessment for this app |
| --- | --- |
| Go + [coder/websocket](https://github.com/coder/websocket) | Sound alternative if Go is the team's stronger operational language; needs a rules port plus golden parity tests. No evidence here that it improves actual player latency. |
| [Nakama authoritative matches](https://heroiclabs.com/docs/nakama/concepts/multiplayer/authoritative/) | More built-in game infrastructure, but adds its runtime/database/account integration. [Official Swift SDK](https://heroiclabs.com/docs/nakama/client-libraries/swift/) exists; pin/build it before assuming Swift 6 compatibility. Less direct reuse of current Swift rules. |
| [GameKit peers](https://developer.apple.com/documentation/gamekit/exchanging-data-between-players-in-real-time-games) | Avoids a new server but retains peer authority/host lifecycle and Game Center requirements. Replacing the custom ordering layer is possible, but not the selected independent-server design. |
| [QUIC](https://developer.apple.com/videos/play/wwdc2021/10094/) / UDP | Potentially useful under measured packet loss; more interoperability/fallback and transport work. Not needed merely to make local taps immediate. |

WebSockets use TCP: packet loss can cause head-of-line delay. WSS is not a promise
of zero latency. Small messages, nearby hosting, buffered schedules and local
prediction address this game's needs first. Only change transport after measured
tail latency under loss demonstrates a remaining problem. Established realtime
games use prediction/reconciliation; [Valve's networking description](https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking)
is a reference for that principle, not a claim about Slither.io's private code.

## Acceptance and removal gates

1. Shared-rule Linux/iOS tests pass, including random repeats, overlapping owners,
   cell occupancy, all progression boundaries and exactly-once scoring.
2. Real WSS harness starts 2/3/4 independent clients with **zero taps**, then plays
   complete matches. Include duplicates, delayed inputs/snapshots, missing Ready,
   roster churn, 1–2s stalls, reconnect, background, clock changes and server/PHP
   restart. No global cancellation for ordinary late input or one slow peer.
3. Under a documented RTT≤150ms / jitter≤50ms profile, target local contact-to-
   feedback p95 within one display frame as a stretch goal (16.7ms at 60Hz,
   8.3ms at 120Hz), local
   Ready next frame, peer Ready p95≤250ms, normal confirmation p95≤300ms and
   opponent-state convergence within 2s after the connection becomes usable.
   These are acceptance targets, not measurements. Separate contact-to-handler,
   handler-to-render submission and physical visible feedback; display-link
   timestamps do not prove glass-to-glass latency. Instrument queue admission,
   presentation frame, original contact, confirm and correction separately.
4. Physical 2/3/4-iPhone Wi-Fi/cellular tests, 60/120Hz, at least 100 starts per
   seat-count with no tap before first target, natural finishes, network handover,
   lifecycle and feature flag rollback. Simulator fixtures are insufficient.
5. Cut over new clients to v2; disable new v1 match creation using an explicit
   compatibility policy. Remove old iOS coordinator, FAST policy/presentation,
   GameKit live transport and associated tests only after shared dependencies are
   separated. Keep Game Center account/publication adapters and historical PHP
   reads. Update current docs when implementation actually changes.
6. Prepare TestFlight from exact reviewed commits only after staging integration
   and device gates. Deployments/host purchase remain separately authorized.

## Implementation tasks

Each child contains scope, tests, completion criteria and explicit dependencies.
All are Backlog; none is represented as implemented by this research change.

| Issue | Deliverable |
| --- | --- |
| [GPT-148](https://linear.app/gptests/issue/GPT-148) | Freeze gameplay and prove conditional scheduling under shared-cell contention |
| [GPT-149](https://linear.app/gptests/issue/GPT-149) | Linux shared-core and native WSS feasibility spike |
| [GPT-150](https://linear.app/gptests/issue/GPT-150) | New deterministic multiplayer engine |
| [GPT-151](https://linear.app/gptests/issue/GPT-151) | PHP tickets, room directory and v2 isolation |
| [GPT-152](https://linear.app/gptests/issue/GPT-152) | Room authority, revisioned Ready and atomic Start |
| [GPT-153](https://linear.app/gptests/issue/GPT-153) | Native Swift socket actor and lifecycle |
| [GPT-154](https://linear.app/gptests/issue/GPT-154) | Shared Arcade presentation, preserved lobby and competitive HUD |
| [GPT-155](https://linear.app/gptests/issue/GPT-155) | Per-seat late-input correction and terminal admission horizon |
| [GPT-156](https://linear.app/gptests/issue/GPT-156) | Durable result settlement and account/moderation integration |
| [GPT-157](https://linear.app/gptests/issue/GPT-157) | Regional WSS staging, observability and rollback |
| [GPT-158](https://linear.app/gptests/issue/GPT-158) | Real network harness and physical 2/3/4-device gates |
| [GPT-159](https://linear.app/gptests/issue/GPT-159) | Cutover, old-layer removal and TestFlight preparation |

## Verification for this research change

Current-source Simulator build and screen inspection completed. Full existing
`Scripts/check.sh` passed (exit 0), including 73 core tests, the native unit suite,
four selected UI regressions, static/configuration checks and Simulator builds.
`git diff --check` passed. The toolchain emitted existing warnings in
`GameCenterAutoLinkControllerTests.swift:80,101` about capture of mutated context,
plus App Intents metadata and LLDB version diagnostics; these were not changed.
Local gate log: `/tmp/pimpopom-v2-audit-check-20260908.log`.
No real multiplayer session, socket service, Linux build, current production
artifact or TestFlight state was verified. No PHP/runtime source was changed.
The old implementation is not removed by this design document.
