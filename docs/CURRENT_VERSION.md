# Current version slice

Snapshot date: 2026-09-09. Local source, external beta state, and deployment are
separate evidence categories.

## Release identity

| Item | Current truth |
| --- | --- |
| Product | PimPoPom for iPhone, iOS 17+, Swift 6 strict concurrency |
| Current beta | `1.02 (25)`, uploaded 2026-09-09; VALID |
| Exact uploaded source | `962a39de80277534dd45eca56ca913217bde1fbb`, clean before archive/export |
| App Store Connect build | `b8afe802-32d4-4538-aaf1-b27182693653`, `APP_STORE_ELIGIBLE`, non-exempt encryption false |
| QA groups / review | Internal QA and External QA both `IN_BETA_TESTING`; beta review `APPROVED`, verified 2026-09-09 |
| Hosted release | v2 shared engine, Vapor service and native socket/SpriteKit integration; unranked playtest |
| Rollback beta reference | Build 20, source `69fe7422719dd4953e90354a2ae3f3c976995db7`; current installability not reverified |
| Production App Store | No production release established by this task |
| Authorized scope | 2026-09-09: Railway EU deployment, separate PHP v2 bridge/migration 023, then TestFlight Internal QA and External QA; no paid-plan upgrade or App Store production submission |

Build 24 is the historical GameKit/v1 beta. Build 25 is the first uploaded v2
binary. Archive identity, hashes and direct Apple status are in [RELEASE](RELEASE.md).

## Current contracts

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
| PHP bridge | Deployed `78b51ee6768d6f049d44b3b8c2d2073e0aac34e0`; migration 023 applied, live configuration enabled; source defaults remain disabled |
| Hosting | Railway Amsterdam, one persistent instance; HTTPS/WSS, restricted runtime and volume restart checks passed. See [deployment record](../Server/DEPLOYMENT_RAILWAY.md) |

Source integration combines the new `MP2*` engine/protocol and `Server/` package
with the replacement iOS controller, socket actor and Arcade SpriteKit board.
The old live GameKit transport, coordinator, FAST seals/frontiers, peer transcript
and v1 client mutation path are removed from build 25. Unrelated
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

Build 25 checks on 2026-09-09:

- `Scripts/check.sh`: 63 core tests and 209 app/UI tests, zero failures or skips;
  named Simulator PimPoPom iPhone 17, iOS 26.5. Log:
  `/tmp/pimpopom-build25-preflight-20260909.log`.
- Service tests after the durable-storage startup guard: 11 on macOS and 11 on
  Linux Swift 6.3.3. Linux process checks proved UID/GID 10001 startup rejects
  unwritable outbox/archive directories, preserves existing evidence, and serves
  health only for the writable control. Logs:
  `/tmp/pimpopom-build25-server-20260909.log` and
  `/tmp/pimpopom-railway-runtime-process-checks.log`.
- The same 209 app/UI tests were rerun into the retained result bundle
  `build/releases/build25-20260909/PimPoPom-build25.xcresult`: 209 passed,
  zero failures/skips. The earlier temporary DerivedData result was no longer
  present when gathering release artifacts; this rerun supplies retained evidence.
- The two-client native loopback socket test ran, not skipped, covering Ready,
  zero-input Start, input receipt and isolated disconnect. Regression tests cover
  immediate prediction, late events after Leave and touch geometry across expansion.
- PHP: Composer gate, 60 SQLite v2 assertions, 63 disposable MariaDB assertions
  and 35 live boundary checks passed. The previous 56-assertion account-deletion
  regression also passed during bridge integration.
- Hosted verification: correct TLS/WSS tuple; unauthenticated/development tickets
  rejected; runtime UID/GID 10001; own volume probe survived one empty-service
  restart. Railway's real service key reached PHP's expected invalid-ticket path.
- Archive/export/upload succeeded. App signature and matching dSYM verified;
  third-party Google Ads/UMP missing-dSYM upload warnings remain. Evidence and
  artifacts are retained in `build/releases/build25-20260909/`.

These checks do not establish real-account matches or physical touch latency.

Available local verification entry points:

- `Scripts/check.sh` and `git diff --check` for the integrated iOS source.
- `swift test --package-path Server -j 4`,
  `bash Server/Scripts/linux-check.sh`, and the real local WebSocket harness.
- Separate PHP `composer check` and disposable MariaDB v2/account-deletion tests.

Remaining gates include genuine player ticket issuance/redemption, complete hosted
matches and logout/deletion revalidation, real result outbox retry/delivery,
queue/load/memory profiling, loss/jitter/clock/
background tests, and physical 2/3/4-iPhone Wi-Fi/cellular matches. Measure 60/120 Hz
behavior on named hardware; the requested 60 Hz service scheduler and UI feedback
goals are not achieved latency guarantees. StoreKit, UMP/Test-mode ads, audio/
haptics, accessibility, legal/asset rights and public release gates also remain.

A service restart loses in-memory matches; the mounted outbox persists. Runtime
and PHP rollback artifacts/backups are retained; live-match draining, sustained
monitoring, retention and secret rotation remain operational acceptance work.
Public privacy/support URLs remain missing and physical reviewer/user sign-in was
not exercised here. Apple reports external beta approval, but this does not prove
gameplay acceptance or App Store production readiness.
