# Build 29 — Multiplayer results, rewards and tutorials

Source: `199bf48f6dccbc0b1a3b234dc12aca3977c16a50`, version 1.02 (29).
PHP and Railway are verified; Apple approved build 29 for both existing QA groups
at 19:02:18 UTC on 2026-09-11. Final UI QA is incomplete under the owner's explicit
no-recheck instruction; see below.

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

Verified PHP source is `bf0ef1b030772872775ab64eaedcbaa1b256e0cf` (implementation
`1860c61`). Additive migration 025 creates a new empty v2 leaderboard and per-owner reward receipts. It does
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

## Verification and remaining QA

- The initial native gate ran 265 tests: 259 passed, six UI failures, zero skipped.
  A focused three-test run passed badge layout and privacy but failed clock-stamp
  feedback before its final correction. Native unit tests passed.
- Tutorial accessibility (`b3b1473`) and stable stamp host (`199bf48`) corrections
  were not Simulator-retested because the owner explicitly requested immediate
  TestFlight distribution without more rechecks. They are implemented, not proven
  UI fixes. Compact/all-theme tutorials and pickup feedback remain QA items.
- Shared source `9b28b21` passed 95 core/47 service tests on macOS and Linux ARM64,
  including readiness checks. Local four-client sockets verify privacy/Ready,
  last-survivor scoring, frozen spectator time, final drain and reuse; retained
  revision-1/2 socket scenarios also pass. No physical/network latency claim.
- PHP Composer, 94 reward/ranking MariaDB assertions and 154 retained Arcade
  assertions pass. Deployment verified 73 source hashes, additive 025 and 45 HTTPS
  boundaries. Railway verified 13 WSS/auth boundaries and unprivileged runtime.
- Actual rollout order: PHP verified first; Railway upload/build started; the owner
  then authorized iOS upload while Railway was compiling, with runtime checks
  afterward. Railway subsequently passed. Apple state is tracked in [RELEASE](RELEASE.md).

Evidence: `build/releases/build29-20260911/qa-status.md`, initial/focused xcresults
and [release records](RELEASE.md). Earlier passing build-28 screenshots are a
historical baseline, not final build-29 visual acceptance. Real-account hosted
reward settlement, physical 2/3/4-iPhone play, timing/audio/haptics/accessibility
and sustained-load acceptance remain open.

Known limitation: deleting a participant before initial match settlement can
make the whole aggregate unavailable; already-awarded other players' value and
new leaderboard rows survive that participant's later deletion. Rollback must
preserve migration 025, receipts, rewards and pending revision-3 outbox evidence.
