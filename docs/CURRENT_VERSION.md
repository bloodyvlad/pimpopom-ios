# Current version slice

Snapshot date: 2026-08-05. This file describes the code and release state at the
documentation cleanup baseline `d182ecf62d8bd360b64b97d8c1080d3389a2c239`.
The cleanup changes documentation only.

## Release identity

| Item | Value |
| --- | --- |
| Product | PimPoPom |
| Platform | iPhone, iOS 17+ |
| Language | Swift 6 with complete strict concurrency |
| Configured version | `1.02 (20)` |
| Bundle / team | `com.otcsoftware.pimpopom` / `APX2925X66` |
| Current TestFlight archive source | `69fe7422719dd4953e90354a2ae3f3c976995db7` |
| Release-record commit | `d182ecf62d8bd360b64b97d8c1080d3389a2c239` |
| App Store Connect build ID | `a98b6bcf-1560-4c17-84cb-dffef47c0778` |
| Beta state | Valid, Beta App Review approved, Internal QA and External QA testing |
| Rollback | Build 19, source `95d9cde7f1b594208461b450b9023a5cec3fabc0` |
| Production App Store | Not released |

Build 20 is the current beta. It shows selected pets and square, glyph-aware
assigned-color cells in Multiplayer waiting/live identity surfaces and improves
Pixel-theme small text. Build 19 remains the available beta rollback.

## Runtime contracts

| Area | Current contract |
| --- | --- |
| Arcade | Build `20260729-1`, ruleset `reaction-proof-v3`, proof 2 |
| Multiplayer | Build `20260729-1`, `multiplayer-own-color-v1`, protocol/proof 1 |
| Multiplayer limits | 2–4 players, 2,500 events, 15 minutes |
| Backend | `https://speedytapper.otcsoft.com`, secure cookie plus CSRF |
| Result trust | Protocol-verified; Multiplayer clean rows are peer-consistent |
| Durable authority | PHP for profiles, replay/results, economy, cosmetics, settlement, and Apple publication |
| Live Multiplayer | GameKit; no PHP traffic per target/tap/HUD update |

Arcade and Zen are playable without sign-in. Ranked Arcade requires a primary
Apple/Google profile with a confirmed nickname and a matching server ticket.
Multiplayer additionally requires a current authenticated Game Center player and
a freshly verified publishing-enabled secondary binding. Multiplayer awards no
coins or achievements.

## Implemented systems

- Pure deterministic `PimPoPomCore` for Arcade/Zen and Multiplayer replay rules.
- SwiftUI app surfaces plus a SpriteKit reaction board.
- Apple and Google primary identity, explicit provider linking, nickname flow,
  session bootstrap, logout, reauthentication, and in-app deletion.
- Automatic nonblocking Game Center authentication at launch, silent reconciliation
  after primary sign-in, and a repeatable **See stats** dashboard action.
- Server-authoritative achievements, themes, pets, wallet, StoreKit credit,
  Remove Ads, and account-bound ad-free state.
- UMP-gated AdMob adapter, fixed 320×50 banner host, and three-completion
  interstitial cadence in configured beta/test lanes.
- Independent theme audio, Sound FX/music/haptic preferences, selectable app
  icons, canonical color glyphs, and pet presentation.
- Multiplayer lobby, GameKit roster, waiting room, fixed coordinator, replayable
  transcript, recovery snapshots, settlement retry, results, and leaderboard.

## Evidence and open gates

Build 20 has focused presentation/cosmetics coverage, inspected Simulator captures,
format/diff checks, archive compilation/signing validation, and successful App
Store processing. The owner explicitly skipped the last spacing UI rerun and the
full `Scripts/check.sh` pass for the archived build.

The following are not closed by that evidence:

- real 2-, 3-, and 4-device/account GameKit matches and settlement;
- measured touch/first-feedback latency on 60 Hz and 120 Hz iPhones;
- StoreKit Sandbox/TestFlight purchase, restore, refund, and Family Sharing;
- UMP first-install/privacy-options and Test-mode ad behavior on physical devices;
- audio/haptic routes, interruptions, Silent mode, and latency on hardware;
- public Privacy/Support/Terms URLs, archive privacy answers, age/ad policy;
- complete public-release rights/trademark review for generated/migrated assets;
- a production App Store submission and post-release smoke test.

## Known Multiplayer latency gap

The current live path is deterministic but visibly delayed:

- all GameKit envelopes use reliable delivery;
- the coordinator holds inputs behind a fixed 250 ms reorder watermark;
- the live loop advances about every 33 ms;
- tap tone, rating, score, target removal, and life feedback wait for the canonical
  event instead of acknowledging the local touch immediately;
- non-coordinators add peer transit to the coordinator and the canonical return;
- planned target time is used as presentation time even when the first rendered
  frame is later;
- a second tap can arrive while the old target still appears active;
- one global target rotates across seats, so an individual sees only every second,
  third, or fourth target.

PHP final replay is not the per-tap latency source. The approved remediation is
the versioned [FAST Multiplayer task](MULTIPLAYER_FAST_TASK.md): immediate local
prediction, a small unreliable input lane, reliable canonical/evidence lanes,
sealed per-seat input frontiers, bounded late-evidence recovery, explicit input
resolutions, live-wire capability rejection, first-render timing, better coordinator
choice, and then concurrent per-seat targets. None is shipped in build 20.

## Repository scope

This repository owns the iOS client and its compatibility documentation. The PHP
implementation remains separate and must not be edited during iOS cleanup or FAST
client work. Any proof/API version required by a later milestone is a separate
backend handoff and release dependency.
