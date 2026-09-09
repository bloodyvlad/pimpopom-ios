# Current version slice

Snapshot date: 2026-09-09. Local source, external beta state, and deployment are
separate evidence categories.

## Release identity

| Item | Current truth |
| --- | --- |
| Product | PimPoPom for iPhone, iOS 17+, Swift 6 strict concurrency |
| Configured version | `1.02 (25)`; authorized Railway/TestFlight candidate, not yet uploaded |
| Last direct App Store Connect check | 2026-09-08: build 24 VALID, uploaded 2026-08-22 |
| Build 24 groups | Internal QA and External QA |
| External beta state | `READY_FOR_BETA_SUBMISSION`; group membership is not proof of external testability |
| Uploaded binary versus source | Uploaded build 24 is the earlier GameKit/v1 beta, not the new v2 candidate |
| Local candidate | v2 shared engine, Vapor service and native socket/SpriteKit integration; unreleased |
| Rollback beta reference | Build 20, source `69fe7422719dd4953e90354a2ae3f3c976995db7`; current installability not reverified |
| Production App Store | No production release established by this task |
| Authorized scope | 2026-09-09: Railway EU deployment, separate PHP v2 bridge/migration 023, then TestFlight Internal QA and External QA; no paid-plan upgrade or App Store production submission |

The September 8 direct check supersedes old notes calling build 22 current or
build 24 never uploaded. Neither a build number nor this documentation identifies
the exact source of an already uploaded archive. Do not attach today's v2 diff
to that historical binary.

## Local candidate contracts

| Area | Contract |
| --- | --- |
| Arcade, unchanged | Build `20260729-1`, `reaction-proof-v3`, proof 2 |
| Zen, unchanged | Local, ephemeral, unranked and unrewarded |
| Multiplayer v2 | `multiplayer-shared-arcade-v2`, protocol 2, 2–4 seats, maximum 900,000 ms |
| Live authority | One persistent Vapor 4 process with the shared pure Swift engine; native WSS client |
| Entry | PHP primary session and confirmed name; no Game Center requirement |
| Result status | Unranked alpha; PHP stores service-reported aggregates, not independently replayed v2 proof |
| Rewards/publication | No Multiplayer coins, achievements, v2 leaderboard writes or v2 Game Center publication |
| Retained history | Read-only client access to historical v1 `peer_consistent_v1` leaderboard rows |
| PHP bridge | Separate local commit `78b51ee6768d6f049d44b3b8c2d2073e0aac34e0`; additive migration 023, disabled by default |
| Hosting | Railway Amsterdam project/service/volume provisioned; deployment and end-to-end verification pending. See [deployment record](../Server/DEPLOYMENT_RAILWAY.md) |

Source integration combines the new `MP2*` engine/protocol and `Server/` package
with the replacement iOS controller, socket actor and Arcade SpriteKit board.
The old live GameKit transport, coordinator, FAST seals/frontiers, peer transcript
and v1 client mutation path are removed in the integration candidate. Unrelated
Game Center linking/publication, Arcade, Zen, identity and economy remain.

## Approved shared-board behavior

The owner confirmed one identical board and accepted waiting for an own-color
opportunity, including on 1×1. Target owners are not a fixed rotation; repeats
are permitted. Targets can overlap on free cells. The board becomes 2×2 after
four total valid hits and 4×4 at 40 seconds. Each seat has its own lives, recovery,
score, streak and challenge baseline. Numerical Arcade configuration/difficulty/
scoring are shared, but contention and delivery headroom can extend personal
target spacing. Exact independent single-player cadence is not claimed.

Ready changes local presentation immediately; the server confirms revisioned
membership and starts without requiring a tap. Input uses first-visible and
original contact times, with bounded server admission and per-seat correction.
Disconnect/reconnect affects that seat, not a peer-wide ACK barrier. Marked traps
remain distinguishable with glyphs off. See the [v2 brief](MULTIPLAYER_V2_REBUILD.md)
for the precise adaptations and [service contract](../Server/README.md) for limits.

## Verification and open gates

Integrated local checks on 2026-09-09:

- `Scripts/check.sh` exit 0: 63 current shared-core tests, builds/configuration/
  formatting/assets, and 209 app/UI tests on PimPoPom iPhone 17 / iOS 26.5 Simulator;
  zero failures or skips. Log: `/tmp/pimpopom-v2-final-check-20260909.log`.
- Real two-client native `MultiplayerSocket` loopback integration ran, not skipped,
  against the local development service on port 18080. It covers Ready/Start,
  zero-score initial play, input receipt and isolated peer disconnect; this is not
  authenticated public WSS/PHP or physical-device evidence.
- `swift test --package-path Server -j 4`: 8 tests passed, including 2/3/4-player
  zero-input start/expiry. Log: `/tmp/pimpopom-v2-integrated-server-tests-20260909.log`.
- Separate PHP bridge commit `78b51ee6768d6f049d44b3b8c2d2073e0aac34e0` passed
  `composer check`, 60 v2 SQLite assertions, 63 disposable MariaDB assertions
  (including single-use concurrent redemption), and 56 account-deletion assertions.
- Regression coverage includes immediate Ready/predicted tap feedback, ignoring
  in-flight room events after Leave, original-contact grid geometry across
  expansion, and bounded pre-disconnect input correction after authenticated rejoin.

The iOS result bundle is
`/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hejlughidecerddzjroxolkasjul/Logs/Test/Test-PimPoPom-2026.09.09_14-48-43-+0200.xcresult`.
These counts belong to this integration candidate, not uploaded build 24.

Build 25 release-candidate checks on 2026-09-09 additionally passed:

- `Scripts/check.sh`: 63 core tests and 209 app/UI tests, zero failures or skips;
  named Simulator PimPoPom iPhone 17, iOS 26.5. Log:
  `/tmp/pimpopom-build25-preflight-20260909.log`.
- Service tests after the durable-storage startup guard: 11 on macOS and 11 on
  Linux Swift 6.3.3. Linux process checks proved UID/GID 10001 startup rejects
  unwritable outbox/archive directories, preserves existing evidence, and serves
  health only for the writable control. Logs:
  `/tmp/pimpopom-build25-server-20260909.log` and
  `/tmp/pimpopom-railway-runtime-process-checks.log`.
- Release-candidate iOS result bundle:
  `/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hejlughidecerddzjroxolkasjul/Logs/Test/Test-PimPoPom-2026.09.09_16-33-50-+0200.xcresult`.

These checks do not establish public hosting, real-account matches or physical
touch latency; those remain separate evidence below and in the deployment record.

Available local verification entry points:

- `Scripts/check.sh` and `git diff --check` for the integrated iOS source.
- `swift test --package-path Server -j 4`,
  `bash Server/Scripts/linux-check.sh`, and the real local WebSocket harness.
- Separate PHP `composer check` and disposable MariaDB v2/account-deletion tests.

The original September 8 v1 audit's checks are historical evidence only. New
unit tests, loopback sockets and Simulator fixtures do not establish public WSS,
authenticated PHP-to-service integration, physical touch timing or deployment.

Remaining gates include production-like TLS/Authorization forwarding, ticket and
logout/deletion revalidation end-to-end, durable outbox failure/restart delivery,
Linux/runtime image verification, queue/load/memory profiling, loss/jitter/clock/
background tests, and physical 2/3/4-iPhone Wi-Fi/cellular matches. Measure 60/120 Hz
behavior on named hardware; the requested 60 Hz service scheduler and UI feedback
goals are not achieved latency guarantees. StoreKit, UMP/Test-mode ads, audio/
haptics, accessibility, legal/asset rights and public release gates also remain.

A service restart loses in-memory matches; only a correctly mounted terminal
outbox survives. Graceful draining, supervision, backup/retention, monitoring,
secret rotation and rollback must be verified after the owner chooses hosting.
