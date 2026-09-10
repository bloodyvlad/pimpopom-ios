# Multiplayer v2 — current gameplay contract

Updated 2026-09-10. Gameplay revision 2 is deployed and available in build 26
to both existing TestFlight QA groups. Build 25 retains revision 1 in separate
compatible rooms; exact source, deployment and Apple evidence is in
[CURRENT_VERSION](CURRENT_VERSION.md). Historical plans and superseded FAST/v1
decisions remain in Git history, not parallel binding contracts.

## Architecture and compatibility

- One identical shared board for 2–4 own-color players. Waiting for a personal
  opportunity on 1×1 is intentional; owners are random, may repeat, and never
  follow a fixed turn sequence.
- Native URLSessionWebSocketTask connects to persistent Vapor 4 authority.
  PimPoPomCore supplies the same pure MP2Engine, protocol DTOs, Arcade
  configuration, difficulty and scoring to server and app. Reuse Arcade's
  SpriteKit board, cell art and original-contact bridge.
- Authentication tuple stays multiplayer-shared-arcade-v2, protocol 2.
  Socket Hello/Welcome additionally negotiate gameplayRevision: omitted means
  legacy 1; build 26 requests and requires 2. Browse/join/resume never mix
  revisions. An older service produces an actionable retry/update message, not a
  silent downgrade. Revision-1 clients retain fixed-color/marked-trap gameplay.
- PHP owns primary identity and confirmed names; Game Center is not required.
  Live GameKit, FAST seals and unanimous peer transcripts are not used. Preserve
  unrelated Game Center linking/publication and historical v1 leaderboard reads.
- All v2 results are service-reported **unranked** aggregates. No coins,
  achievements, v2 ranked season, leaderboard writes or Game Center publication.
  PHP does not independently replay v2 input or establish human verification.

## Revision-2 gameplay

Start 1×1, expand to 2×2 after four total correct hits, and to 4×4 at 40 seconds.
Each seat has its own score, lives, streak, reaction statistics, recovery and
post-50-second challenge-hit baseline. Use GameConfiguration.standard,
resolveDifficulty and ReactionScoring; do not copy or accelerate their numbers.

### Tempo and targets

Each accepted correct hit samples Arcade's quiet delay from its current phase
and applies it to **all newly issued targets**, not only that player's next
target. This prevents another already-due owner from replacing the hit tile
almost immediately. Quiet ranges are 550–1,100, 550–1,000, 500–950, 475–900 and
525–950 ms across the 0/10/20/30/40-second phases; after 50 seconds use Arcade's
challenge-hit formula and floors. Response windows also use the unchanged Arcade
formula, down to 200 ms. Full numbers remain in [GAMEPLAY_SPEC](GAMEPLAY_SPEC.md).

Already announced targets retain immutable activation/response windows and may
overlap or activate almost simultaneously on different free cells. At most one
unresolved target per owner; never overwrite an occupied cell. Independent due
times, random arbitration and oldest-due priority after two seconds avoid fixed
turns. Occupied targets retry after 50 ms plus delivery headroom. The common quiet
interval is a floor, not a guarantee of independent personal cadence: delivery,
cell contention and recovery can extend the wait. Default preannouncement lead
is 250 ms, bounded by 750 ms.

### Colors and decoys

Colors remain stable for the first ten seconds. A later valid hit selects a new
color excluding **all** assigned player colors and all live decoy colors. If no
alternative is free, retain the current color, as Arcade does. A late correction
cannot recolor an already issued target. Colors remain distinct even for seats
currently out or disconnected.

Decoys use only non-player colors and normal optional color glyphs, with no
exclamation marker. They last Arcade's 1–3 seconds and survive correct taps. One
named beneficiary receives the unmultiplied 550-point natural dodge. Use one global
Arcade decoy cap bounded by cellCount minus one, including four-player 2×2 play.
Personal mistakes/disconnection clear that seat's decoys without credit.
A just-expired decoy cell is avoided for its beneficiary's next target when
another free cell exists. Other-player targets are not decoys: wrong-color taps
cost only the tapping seat's life and never consume the owner's target.

### Lives, hearts and spectating

Seats start with three lives and retain Arcade's 1,500 ms personal recovery.
Neutral hearts provide occasional competition for any living, non-recovering
player: the first server-admitted claim restores one life up to three. A player
already at three consumes the pickup without exceeding the cap. Competing,
duplicate or expired claims do not become empty-cell mistakes. No heart grants
points, hits, streak steps or rewards, and no heart revives an eliminated seat.

Heart opportunities are sampled every 12–20 seconds from the previous issuance,
starting after the same random initial delay. At most one heart is live, for
three seconds, on 2×2 or larger. Placement requires at least two free cells,
leaving one for targets; unavailable opportunities retry after 250 ms. Original
pre-expiry contacts retain the ordinary bounded delivery grace, but never steal
an already admitted claim. Misses remain actual cumulative life losses and may
exceed three. The separate PHP migration 024 and validator update must be verified
before revision-2 rollout; the initial-life and restored-life cap remains three.

An eliminated local seat sees **YOU LOSE** and **SPECTATING** over the board while
the remaining players continue. Keep the logo and Menu control above the live
HUD, all 2–4 players' competitive information, and the existing hub/lobby design.
All-out or 900,000 ms ends play after the final input-admission horizon.

## Rooms, authentication and recovery

The socket service alone owns membership, revisioned Ready and atomic Start.
Ready responds locally immediately, then reconciles the server's intent/roster
revision. The creator starts only a full connected Ready roster; duplicate Start
returns the same countdown. Roster changes cancel it. No tap or peer ACK is
needed to start or advance the match.

The directory contains only compatible, connected, non-full waiting rooms and
pushes changes without a refresh. Create/quick Leave, disconnect, full/finished
rooms and subsequent creation must not leave stale joinable entries. A valid
new create/join may replace the same player's abandoned lobby on another socket,
not a live match; retain other members and transfer host ownership where needed.
Terminal evidence remains until outbox persistence; old-room cleanup cannot detach
a connection from its newer room. Revision-2 Leave sends ordered left acknowledgement
so delayed Create responses cannot reopen an abandoned room. Clients must also
clear pending admission when its socket is replaced.

An uninitialized native session is **checking sign-in**, not signed out. Restore
and validate the PHP session before presenting a login requirement. Ticket expiry,
rate limiting, service failures and primary revocation are different conditions;
only primary-session verification establishes the need to sign in again.
Service validation remains fail-closed, isolated to that connection, every
15 seconds and before resume. Transient failure may reconnect but never claims
that every player's match failed authentication.

Reconnect authenticates a fresh ticket, then rotates a player/room-bound resume
credential and generation. Disconnect pauses only that seat for a 15-second
grace while peers continue; intentional Leave eliminates only that seat.
Stale socket/task generations cannot mutate a newly connected session.

## Input and persistence boundaries

Project local target feedback before network I/O. Record first-visible and
original contact timestamps; never score from network arrival time. Server
receipts/snapshots reconcile predictions without duplicate sound/haptics/score.
Hearts disappear locally on claim but only authority changes lives.

Input admission permits at most two seconds of receipt lateness and 750 ms of
presentation allowance; it does not extend the 200–1,000 ms reaction window.
Exact-deadline contact is late. Per-seat journal correction can remove one
provisional expiry; target cells remain reserved through the admitted visible
window. Final admission drains for 2,750 ms. These timestamps are client evidence,
not proof of human-visible frames or anti-cheat strength; ranking remains off.

The service requests 60 Hz advancement and 10 Hz periodic snapshots, with immediate
critical changes, bounded queues and no disk/network await inside room mutation.
These are settings, not measured latency guarantees. PHP accepts idempotent
immutable unranked aggregates through the service-only bridge; live taps never
enter PHP. A private persistent outbox retains failures and archives only an
acknowledgement of the matching unranked match. See [Server/README](../Server/README.md).

## Release acceptance

Release from exact clean commits only after core, iOS, macOS/Linux service,
WebSocket and separate PHP/MariaDB checks. Verify PHP 024 compatibility before
new gameplay, then Railway health/authenticated sessions and the actual processed
TestFlight build/groups. Neither this document nor a build number proves delivery.

Physical 2/3/4-iPhone Wi-Fi/cellular tests must cover rapid create/leave/recreate,
Ready, zero-tap Start, color/decoy/heart competition, spectator return, background,
loss/jitter, session revocation and result retry. Measure original-contact local
feedback and peer convergence separately on named 60/120 Hz hardware. Sub-frame
feedback and convergence goals remain unmeasured until that evidence exists.
A service restart still loses in-memory matches; only outbox evidence persists.
Drain, sustained load, multi-region failover and live-match recovery are not
established by this unranked beta.
