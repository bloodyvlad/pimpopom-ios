# Multiplayer results, rewards and tutorials — local candidate

Status: implemented locally; native UI verification pending, not deployed or uploaded.
The released beta remains 1.02 (28); this branch deliberately has no release-number bump.

## Accepted rules

- The last living player continues until their final life is lost (or the existing
  15-minute limit). Their additional points count. Highest final score wins even
  if eliminated earlier. Score ties share competition places (1,1,3); tied winners
  see Draw. Survival is a statistic, never a winner tiebreaker.
- Eliminated players spectate, with small badge stamps. No You lose before final
  results. The local finalizing state is not spectating. Live crowns identify the
  highest score, including predicted local points; zero-score ties have no crown.
- Private/public is edited by the host beside the created room's code. The server
  checks room identity/revision and waiting phase, updates directory visibility
  atomically, and preserves Ready. Private rooms stay exact-code searchable.
- Multiplayer Missed, both modes' +1UP/Lives highlight, and Arcade Slowing down are
  1.5-second, theme-aware, noninteractive feedback. Full-life heart consumption and
  losing a shared-heart race do not show a false life award.
- Pixel Pet Shop and Themes icons use code-native pixel artwork; other themes
  retain their existing symbols. No new downloaded or generated assets.
- Arcade/Multiplayer entry uses separate guided practice and remembered opt-outs;
  Settings can replay either. Practice is untimed and creates no run, socket, reward
  or leaderboard entry. Demonstrations share actual streak and clock rules.

## Authority and compatibility

Protocol 2 is unchanged. New clients require gameplay revision 3 and room discovery
2. Revisions 1/2 retain original gameplay, welcome discovery 1 and separate rooms.
Revision 3 exposes final reasons, server-derived connected/alive milliseconds,
peak multiplier and an explicit life-awarded receipt. Input grace also covers
original pre-death heart contacts and pre-time-limit target contacts.

The service signs in through the existing PHP bridge. It captures each player's
economy generation at actual match start, then sends an immutable result revision 2
with reward policy `multiplayer-alive-minute-v1`. PHP accepts only the trusted service;
clients never submit coin amounts, eligible time, results or balances.

The isolated PHP candidate is `/Users/vlad/Documents/SpeedyTapper-mp29-rewards`.
Its clean commit is `bf0ef1b030772872775ab64eaedcbaa1b256e0cf` on `codex/mp29-rewards`
(implementation `1860c61`, followed by dated verification notes).
Migration 025 adds a new empty v2 leaderboard and per-owner reward receipts. It does
not erase old data, Arcade results or purchased value. Switching the client to this
new lane provides the requested fresh visible leaderboard without destructive cleanup.

Eligible completed competitive play earns 2 coins per cumulative connected/alive
minute, with independent sub-minute carry. No rewards for tutorial, disconnection,
spectating or stale/missing economy generation; no old-result backfill. Immutable
credits participate in existing earned-wallet/debt/reset reconciliation. No Multiplayer
achievements or Game Center publication. Trust label is `server_reported_v2`, not
PHP-replayed, peer-consistent, human-verified or bot-proof.

Public GET `/api/mobile/v2/multiplayer/leaderboard` retains top-five/own-context
presentation. Score ranks may tie; unique positions prevent duplicate row identity.
Unsupported speed-rating counts are not invented. Authenticated participant-only GET
`/api/mobile/v2/multiplayer/results/{matchID}` returns only that player's saved reward.
The app uses bounded retries and refreshes its authoritative session/wallet; final
scores and Menu never wait for durable settlement. A failed wallet refresh stays retryable.

## Verification and release gates

Implemented areas: `App/Features/HowToPlay*`, `Multiplayer*`, `App/Gameplay`, shared
stamp/icon design components, leaderboard models/client, shared core engine, Vapor
service/outbox and isolated PHP reward/ranking services. Focused unit/UI, pure core,
real socket, result-contract and disposable MariaDB tests accompany the changes.

- iOS branch: `codex/mp29-gameplay-tutorials`. Core/service source comes from clean
  `9b28b210e44919cb6d1719ffb97054ab35764de1`, integrated as `6d4c6e8`.
- Local macOS: 95 core and 47 service tests pass. Logs:
  `/tmp/pimpopom-mp29-core-final.log`, `/tmp/pimpopom-mp29-server-final.log`.
  Strict Swift formatting, asset/hash provenance, ad configuration, property-list
  validation and `git diff --check` pass.
- Linux ARM64: the exact final core/service source passes 95 core, 47 service,
  unprivileged readiness/HTTP health and entrypoint checks. Evidence:
  `/private/tmp/pimpopom-mp29-health-linux.FZtB1K/VERIFICATION.md`.
  Image `ef27a233d960fa2241a6ad9b910cb7274032b4421d4c5333f3cf481e713719c0`
  is a local verification image, not a deployed artifact. AMD64 is unverified here.
- Four real local sockets pass privacy/Ready, all four scoring, last-survivor
  continuation, frozen spectator time, final drain and room reuse. Retained
  revision-1/2 and 2/3/4-player socket tests also pass. Logs:
  `/tmp/mp29-final-four-client.log`, `/tmp/mp29-legacy-sockets.log`.
- PHP: Composer check and new 94-assertion MariaDB upgrade/reward/ranking suite
  pass, including the actual Swift aggregate, concurrent/idempotent credit,
  transaction rollback, debt/reset, paid-value preservation and deletion isolation.
  Retained Arcade 154, v2 authentication 132, Game Center 14 and reset harness pass.
  Nickname's eight assertions pass using a temporary TCP-readiness wrapper after
  the unchanged stock harness twice hit its startup-readiness race.
- App and test targets compile on iOS Simulator; actual XCTest/UI execution is
  pending a running Simulator, as required by the iOS debugger skill. Both simulators
  were shut down when checked. `Scripts/check.sh` now includes the tutorial UI class.
- Final build-for-testing log (2026-09-11):
  `/Users/vlad/Library/Developer/XcodeBuildMCP/workspaces/SpeedyTapper-093dcbfd6194/logs/build_sim_2026-09-11T18-26-53-045Z_pid47808_66f87a43.log`.
  The incremental build reports no warnings/errors; earlier full compiles retained
  two pre-existing Game Center test capture warnings. No physical-device claim.
- Required before release: full `Scripts/check.sh`, compact/four-theme tutorial,
  multiplayer badges/privacy and pickup feedback inspection; fresh 2/3/4-client
  checks and physical-iPhone timing/audio/touch acceptance.
- Deployment order: authorized exact clean PHP artifact/migration/verification on
  **speedytapper.otcsoft.com only**, then compatible Railway source, then newly
  numbered TestFlight build. No production or Apple writes occurred in this update.
- Existing limitation: deleting a participant before the service stores a match
  can make the shared aggregate unavailable; already-awarded other players' value
  and new leaderboard rows survive that participant's later account deletion.
