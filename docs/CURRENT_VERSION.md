# Current version slice

Updated 2026-09-12. Source, hosted deployment and Apple distribution are separate
evidence; later documentation commits do not change the uploaded binary.

## Build 30 release state

Build 30 changes presentation only: a small centered coin and earned amount above
the Multiplayer roster, a smaller outcome badge/title on compact screens, no
seconds-carry copy, tutorial guidance on spending coins, Pixel trophy/profile
icons, and centered mode names without subtitles. Receipt/account guards and the
build-29 gameplay, reward, identity, StoreKit and advertising contracts are unchanged.

| Item | Current truth |
| --- | --- |
| Product | PimPoPom, iPhone/iOS 17+, Swift 6 strict concurrency |
| TestFlight | `1.02 (30)`, VALID / APP_STORE_ELIGIBLE |
| Binary source | `79b02abc524954547fc49b5f67ca3d587f121c41`, clean optimized Staging |
| Apple build ID | `d379664b-d895-4f0a-b84b-072ebff9334c`; uploaded 2026-09-12 10:28:12 UTC |
| QA groups / review | Internal QA and External QA IN_BETA_TESTING; review APPROVED; verified 2026-09-12 10:31:38 UTC |
| Notifications / public link | Automatic notification enabled; existing external public link preserved |
| Retained Railway source | `9b28b210e44919cb6d1719ffb97054ab35764de1` |
| Retained Railway deployment | `9ec61784-391e-4be0-bdbe-deb227487f69`, one Amsterdam replica; not redeployed for build 30 |
| Retained PHP source | `bf0ef1b030772872775ab64eaedcbaa1b256e0cf`; only `speedytapper.otcsoft.com`; not redeployed |
| PHP schema | Existing ledger 001–025 retained; no migration, season reset or account-value change |
| Previous beta | Build 29 is the compatible reference beta; Arcade v3/v4/v5 retained |
| Production App Store | Not submitted or released by this task |

Exact artifacts, checksums and rollback boundaries: [RELEASE](RELEASE.md) and
[Railway record](../Server/DEPLOYMENT_RAILWAY.md). Feature detail: [MP29](MP29_GAMEPLAY_TUTORIALS.md).

## Retained gameplay and network contracts

- Arcade: `normal`, compatibility build `20260729-1`, explicit
  `reaction-proof-v5`, proof 3. Legacy omitted ruleset selects v3/proof 2;
  retained v4/proof 3 is unchanged. Ranking, coins and achievements remain PHP-owned.
- Hearts/clocks appear only on the actual 4×4 board. An active 2×2 target across
  40 seconds remains ineligible. Opportunity cadence/effects are unchanged;
  an overdue pickup may appear soon after 4×4 becomes available.
- Arcade alone has clocks, with a theme-matched rewind arrow; hearts match HUD
  artwork in all themes. Zen is local, ephemeral, unranked and unrewarded.
- Multiplayer: `multiplayer-shared-arcade-v2`, protocol 2, gameplay revision 3,
  2–4 seats, at most 900,000 ms. Revision-1/2 clients use separate original-rule rooms.
  One persistent Vapor authority, native WSS and the shared Arcade SpriteKit board.
- One identical board: 1×1, 2×2 after four total correct hits, 4×4 at 40 seconds.
  Owners are random, may repeat, and may overlap on free cells. Waiting for an
  own-color opportunity is intentional. Arcade quiet delays and speed progression
  are shared; cell contention and delivery headroom can extend personal spacing.
- After ten seconds, successful hits rotate assigned colors when safe. Player
  colors stay unique; persistent decoys exclude every player's color and have no
  exclamation marker. Neutral hearts restore one life up to three for the first
  server-admitted claim; losing claims are not mistakes and eliminated seats stay
  spectators. The last living player keeps scoring until all are out or time expires,
  after input admission drains. Highest final score wins; equal scores share places.
  No premature loss while spectating. Multiplayer has no clocks or achievements.
- A valid PHP primary session and confirmed public name suffice; no Game Center
  prerequisite. Session refresh, ordered Leave, connection-generation fencing and
  pushed connected/non-full waiting lists remain. No peer FAST/tap transcript path.
- Completed competitive revision-3 results enter a fresh global v2 leaderboard
  and earn two coins per cumulative connected/alive minute with separate carry.
  Countdown, disconnection, spectating, tutorial and stale/missing economy generations
  do not mint coins. PHP derives immutable idempotent credits; the client submits no
  amount. Trust is `server_reported_v2`, not independent replay or human verification.
  No old-result backfill or Game Center publication. Outbox survives restarts;
  live rooms do not. Final scores/Menu never wait for receipt/wallet refresh.

## Rooms and UI

Multiplayer rewards appear only after a validated eligible receipt, using its exact
coin amount, including zero. Repeated receipt refreshes replace presentation rather
than add value; wallet refresh may finish later. The centered 32-point coin and
earned amount stay above the scrolling roster. Compact screens reduce the outcome
badge/title and spacing; Leaderboard/Menu remain outside the roster. Seconds carry
still belongs to the server economy but is no longer shown here. Arcade and eligible
Multiplayer tutorial reward steps now say "Spend them in Pet Shop or purchase Themes."
Pixel trophy/profile icons retain signed-in/out state and accessible button labels.
Arcade, Zen and Multiplayer menu buttons show centered names without subtitles.

Rooms have stable eight-character codes, visible in waiting/live/results screens.
Copy/Share is available in the waiting room. Public rooms support creator-name
substring search; exact case-insensitive code/full UUID can find public or private
joinable rooms. Private rooms never appear in browsing, nickname or partial-code
search. Anyone signed in with the full code may join; no password is required.
Build 29 requires advertised `roomDiscoveryRevision:2`; the host can change privacy
beside the waiting-room code without resetting Ready. Older clients retain discovery 1.
Debounced query/request fencing prevents stale responses from restoring old lists.
On compact phones the roster scrolls while code, Leave, Ready and Start remain
reachable. Logo/Menu and competitive badges remain; elimination shows Spectating,
while Win/Lose/Draw follows final scores. Arcade/Multiplayer have separate safe,
untimed tutorials and remembered opt-outs, replayable from Settings; Zen is unchanged.

## Verification and remaining gates

- 95 core tests and initial build/static checks passed. Five focused receipt/leaderboard
  tests and all eight compact results scenarios passed. All eight final 750×1334
  iPhone SE (3rd generation) / iOS 26.5 captures were reviewed, plus a manual Pixel
  menu capture. The compact menu query was corrected in tests only.
- The owner accepted the UI, stopped the final full check and approved both QA groups.
  The iPhone 17 / iOS 26.5 result is **263 tests: 259 passed, three failed, one skipped**;
  exit 65. The all-theme tutorial wait timeout is unresolved, distinct from the
  Arcade test's termination signal and the test-runner invalid-device/Mach-server
  failure. No fully passing final-source gate or interruption-only explanation is claimed.
- Archive and inspected local distribution export passed signature, app/dSYM UUID,
  12 privacy manifests, zero private/test files and encryption-exemption checks.
  The distribution export has `get-task-allow:false`. Apple accepted the upload;
  processing is VALID, beta review APPROVED and both existing QA groups are
  IN_BETA_TESTING, directly verified 2026-09-12 10:31:38 UTC.
- Read-only PHP health, signed-out session, Arcade leaderboard and Multiplayer v2
  leaderboard returned HTTP 200 JSON on 2026-09-12 10:06–10:07 UTC. Railway health
  returned HTTP 200/ok with protocol 2, gameplay revision 3 / result revision 2.
  Existing deployment references above are retained build-29 evidence; these reads
  do not independently reverify source hashes, schema or runtime identity.

Evidence: `build/releases/build30-20260912/` in the binary worktree, including
`verification-notes.md`, `compact-final.xcresult`, `compact-attachments/`,
`check-final-summary.json`, archive/export inspections and `apple-final-state.json`.
Build-29 service/core,
MariaDB, deployment and incomplete UI evidence remain historical in RELEASE.md.
No backend, schema, season, account-value, advertising or StoreKit change occurred.
Still validate real-account 2/3/4-iPhone hosted matches/rewards, Wi-Fi/cellular
latency, reconnect/logout, pickups, accessibility and physical 60/120 Hz behavior.
No production App Store submission, live-ad activation, paid-plan upgrade or
production/legal acceptance is claimed.
