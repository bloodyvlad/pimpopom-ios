# Multiplayer v2 room service

Local implementation candidate; no hosting, production migration, deployment or
TestFlight release is implied. This is the separately versioned authoritative
Swift service for `multiplayer-shared-arcade-v2`, protocol `2`. All results remain
unranked and award no coins, achievements or Game Center publication.

## Run locally

Requires Swift 6.3.3 (locked dependency manifests include Swift 6.2 packages).
macOS 15+ or Linux is supported by this package. From the repository root:

```sh
cd Server
swift test -j 4
MP2_DEV_AUTH=1 MP2_PORT=18080 swift run PimPoPomRealtime
```

In another terminal:

```sh
curl http://127.0.0.1:18080/health
MP2_WS_URL=ws://127.0.0.1:18080/multiplayer/v2 node Server/Scripts/ws-harness.mjs
```

The default bind is `127.0.0.1:8080`; port 18080 avoids an existing local service.
Development tickets are exactly `dev:<UUID>`, such as
`dev:00000000-0000-4000-8000-000000000001`. They are synthetic fixtures and require
the explicit `MP2_DEV_AUTH=1` environment variable. Startup rejects development
authentication with any non-loopback bind. Without that variable, startup
requires HTTPS PHP introspection/validation endpoints and a service secret.
Never set development auth on a hosted deployment.

`Package.resolved` locks all transitive dependencies; Vapor is pinned to stable
`4.121.4`. The service imports `../Packages/PimPoPomCore`, the exact same pure
Swift protocol and engine used by the iOS client.

## Connection contract

Connect to `ws://127.0.0.1:18080/multiplayer/v2` for local fixtures. A hosted
instance requires a WSS/443 reverse proxy with WebSocket upgrade support and
TLS; the container listens on its private HTTP port. A reverse proxy must not
log ticket or credential bodies. Tickets never appear in a URL.

Wire values use the shared `MP2ClientMessage`/`MP2ServerMessage` Codable enums.
Examples of Swift's enum JSON encoding:

```json
{"hello":{"ticket":"dev:00000000-0000-4000-8000-000000000001","protocolVersion":2}}
{"create":{"capacity":2}}
{"ready":{"value":true,"intentID":1,"rosterRevision":2}}
{"start":{}}
{"ping":{"id":1,"clientTimeMs":1000}}
```

Hello must arrive within five seconds and must authenticate before any action.
Welcome contains the connection ID and monotonic server time. List/create/join
use this same authenticated socket. Room membership is the sole Ready authority.
Server enums with an unlabeled associated value wrap it in `_0`, e.g.
`{"room":{"_0":{...}}}`; the iOS app decodes shared DTOs directly.

Create/join emits `resumeCredential` before `room`; input emits `receipt` before
the resulting `snapshot`. Only the creator starts a full 2/3/4-player room with
every seat connected and Ready. Ready uses a monotonically increasing intent ID
and the current roster revision. Duplicate Ready cannot reverse newer intent.
Duplicate Start returns the same match and countdown. Roster changes cancel a
countdown; zero input activity never blocks starting or advancing.

Reconnection first authenticates a new socket with a fresh ticket, then sends
`resume(roomID, credential, generation)`. The credential is bound to the
authenticated player and room epoch; success rotates the credential/generation,
fences the previous connection and emits the latest authoritative snapshot.
Old input generations cannot enter the engine. The client must discard old
generation predictions when it installs the reconnect snapshot. Disconnects
suspend only that seat's opportunities; peers continue. A 15-second grace allows
return, then only the absent seat is eliminated. Intentional Leave eliminates
that seat immediately. Completed rooms stay available for 60 seconds after
completion and are removed only after their result is journaled.

The service advances at a requested 60 Hz and emits periodic snapshots at a
requested 10 Hz, plus immediate target/decoy/phase changes and input receipts.
These are scheduler settings, not measured timing guarantees. Every room and
connection mutation is serialized by `RoomService`; it never awaits disk,
network, or a socket writer. One ordered reader and writer serve each socket.
The bounded outbound mailbox coalesces consecutive periodic snapshots while
preserving critical event order. A slow peer cannot block healthy players.

Limits: 256 simultaneous connections, 64 rooms, 16 KiB frames, 64 queued input
frames, 64 queued output messages and 120 actions/second/connection. Clients send
application ping messages at least every 30 seconds (the app/harness uses one
second). WebSocket ping/pong runs every five seconds separately. Invalid JSON,
invalid authentication and overflow close only the affected connection. Error
codes are typed descriptive strings; ordinary tap failures never abort peers.

## PHP integration configuration

| Variable | Value / purpose |
| --- | --- |
| `MP2_TICKET_INTROSPECTION_URL` | HTTPS `/api/internal/multiplayer/v2/tickets/redeem` |
| `MP2_SESSION_VALIDATION_URL` | HTTPS `/api/internal/multiplayer/v2/sessions/validate` |
| `MP2_RESULTS_URL` | Optional HTTPS `/api/internal/multiplayer/v2/results` |
| `MP2_SERVICE_KEY` | Secret with at least 32 characters; bearer service authentication |
| `MP2_BIND` / `MP2_PORT` | Interface and port; production container uses `0.0.0.0:8080` behind TLS proxy |
| `MP2_OUTBOX_DIRECTORY` | Durable private volume; default `data/outbox` |

The iOS client requests a single-use ticket from
`POST /api/mobile/v2/multiplayer/tickets` under its PHP cookie/CSRF session.
Redemption sends ticket, protocolVersion and ruleset; the authenticated response
contains playerID, name, nullable petID, sessionBinding, expiresAt (Unix seconds),
protocolVersion and ruleset. Exact capability checks reject incompatible peers.
Session validation runs every 15 seconds and immediately before every resume,
with a five-second request timeout,
including PHP's logout/deletion revocation. Fresh ticket authentication precedes
every resume. Network/auth validation failure closes the affected connection.

Final results contain immutable match ID, protocol/ruleset, duration, explicit
`rankingEligible:false`, and stable-seat UUID/score/lives/hit/miss/dodge/reaction
fields. The server queues these off the input path. A private serial filesystem
queue writes one sorted JSON file per match using atomic replacement; same-data
retries are idempotent. No names, pets, tickets or session bindings are journaled.
Restart retries pending files every five seconds when `MP2_RESULTS_URL` is set.
The outbox archives a file only after PHP acknowledges the same match ID as
`stored_unranked` with ranking disabled. HTTP failures and conflicting results
retain evidence for operator recovery.

Pending evidence is capped at 1,000 files and is never evicted to admit new
results. A full/unwritable outbox retains completed room state and blocks cleanup
until storage recovers. Acknowledged copies retain at most 1,000 files/30 days.
Atomic JSON writes protect against partial replacement; filesystem/power-loss
durability still depends on the host and volume. In-progress rooms are in memory;
a service restart loses those rooms and must be shown as an infrastructure
interruption, never fabricated results. Production drain/HA/backups and durable
in-flight recovery remain release gates.

## Verification and container

```sh
# macOS actor/configuration/outbox tests
swift test --package-path Server -j 4
# Linux service + shared rules tests, with an allowlisted Docker context
bash Server/Scripts/linux-check.sh
# Runtime image; use BuildKit's Dockerfile-specific ignore file when available
docker build -f Server/Dockerfile -t pimpopom-mp2:local .
```

The runtime runs as an unprivileged user and requires a mounted `/app/data`
volume. It intentionally cannot start with production bind plus development
authentication. Configuration should arrive from a secret manager/environment;
no credential is built into the image. `/health` exposes protocol, ruleset,
ranking flag and room/connection counts. Do not publish the private port without
the authenticated TLS reverse proxy and operational review.

The real local WebSocket harness covers 2/3/4 clients, no-tap matches, immediate
Ready, duplicate Start, reconnect credential rotation and malformed/unauthenticated
socket isolation. Unit tests cover stale Ready, countdown invalidation, personal
disconnect grace, session revocation, coalescing and restart/idempotent outbox.
Run `Scripts/check.sh` in the integrated iOS checkout separately; this package
does not establish app visual, physical device, 60/120 Hz, WSS, production PHP,
loss/jitter, load, or latency acceptance. Ranking remains disabled until those
gates and the input-admission/prediction invariants in the v2 brief are proven.

API references: [Vapor WebSockets](https://docs.vapor.codes/advanced/websockets/),
[Vapor Docker deployment](https://docs.vapor.codes/deploy/docker/), and the
checked-in shared Swift source remain the relevant framework/protocol sources.
