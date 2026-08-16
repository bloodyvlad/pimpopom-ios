# Current version slice

Snapshot date: 2026-08-16.

## Release identity

| Item | Current truth |
| --- | --- |
| Product | PimPoPom for iPhone, iOS 17+, Swift 6 strict concurrency |
| Configured candidate | `1.02 (23)` |
| Candidate state | Tested source only; not archived or uploaded |
| Current TestFlight | `1.02 (22)`, VALID, Internal QA only |
| Build 22 source / ASC ID | `c20fcbeb7f053e7b0f50cac1be8942854909e82a` / `f1217f45-1dc0-4ee4-8e15-d59343766146` |
| Rollback beta | Build 20, source `69fe7422719dd4953e90354a2ae3f3c976995db7` |
| Production App Store | Not released |
| Open acceptance | Physical 2/3/4-device, reconnect/network transition, and 60/120 Hz tests |

Build 22 proved immediate local presentation but is not the stability target: QA
observed frequent `Syncing`, abrupt match termination, delayed Ready, and a lobby
crash. Build 23 is the corrected candidate and must not be described as deployed.

## Current contracts

| Area | Contract |
| --- | --- |
| Arcade | Build `20260729-1`, `reaction-proof-v3`, proof 2 |
| Multiplayer | Build `20260729-1`, `multiplayer-own-color-v1`, protocol/proof 1 |
| Multiplayer limits | 2–4 players, 2,500 events, 15 minutes |
| Result trust | Protocol-verified; clean Multiplayer rows are peer-consistent |
| Live transport | GameKit only; PHP receives no live targets or taps |
| Durable authority | PHP for identity, results, settlement, economy, and cosmetics |

## Build 23 Multiplayer behavior

- Local contact is acknowledged on the next display frame; canonical score, lives,
  streak, and transcript change only after deterministic reconciliation.
- Missing unreliable traffic is expected. Reliable evidence, cumulative seals,
  exact acknowledgements, journals, and causal snapshots repair it.
- Recovery is invisible below 1 second. From 1–15 seconds a small nonblocking
  `Catching up` HUD appears while eligible input remains interactive.
- A real disconnect shows `Reconnecting`, pauses logical play, and gets 15 seconds
  to recover. Invalid or contradictory protocol data still cancels immediately.
- Ready intent responds locally and queues until live-wire compatibility is
  unanimous. Clock loss/reorder are diagnostics, not a startup rejection.
- GameKit callbacks are relayed onto `MainActor` and rejected after their match or
  matchmaking generation becomes stale.
- Start, pause, resume, finish, terminal cancel, evidence, and resolutions remain
  retained until the intended recipient acknowledges an exact attempt. Snapshots
  are chunk-complete, bounded, and cannot rewind newer plan/pause state.
- Resume advances after its reliable send is physically accepted for every intended
  peer; exact ACK recovery continues in the background without blocking play.
- Multiplayer hit fly-outs use the same straight, borderless points/rating glow as
  single player. The back button is complete in every theme. HUD-to-board layout
  spacing remains exactly 5 points.

The GameKit live wire is capability-gated; PHP tuples and proof semantics are
unchanged. There is no custom LAN path, host migration, or live PHP relay.

## Evidence and open gates

The source gate is `Scripts/check.sh` plus `git diff --check`. It covers the core
package, native unit suite, generic Simulator build, asset/privacy/ad configuration,
four-theme Multiplayer layout/fly-outs, catch-up interaction, and all-theme back
button regressions on the named iPhone 17 Simulator.

Still required before calling FAST physically accepted or production-ready:

- real 2-, 3-, and 4-device GameKit matches through natural settlement;
- same-Wi-Fi and different-network reconnect, background/foreground, and network
  transition tests;
- measured touch/feedback timing on 60 Hz and 120 Hz iPhones;
- StoreKit Sandbox, UMP/Test-mode ads, audio/haptics, public legal metadata, rights,
  and production App Store review gates.

This repository owns only the iOS client and compatibility snapshot. The PHP
implementation is separate and is not changed by this release.
