# Native architecture

This document describes the current targets and runtime boundaries. It contains no
future module plan.

## Repository shape

```text
PimPoPom.xcodeproj / project.yml
App/
  Design/       theme, cell, pet, typography, reusable views
  Features/     SwiftUI screens and feature coordinators
  Gameplay/     SpriteKit board, touch bridge, local run coordinator
  Services/     HTTP, identity, GameKit, StoreKit, ads, audio, preferences
  Testing/      Debug-only fixtures
Packages/
  PimPoPomCore/ deterministic rules and replay package
Tests/          app unit and UI tests
```

Only `PimPoPomCore` is a separate package. The other names are app-target folders,
not independent modules.

## Dependency rules

| Area | Owns | Must not own |
| --- | --- | --- |
| Core | Rules, configuration, injected randomness/time, state transitions, score, proofs, Multiplayer reducer/coordinator | Apple UI, network, storage, audio, ads, purchases |
| Gameplay | SpriteKit nodes/layout, render boundary, UIKit touch timestamp bridge, local feedback | Rule duplication, server submission |
| Features | Navigation, screens, presentation state, user intent | Authoritative score, value, identity, settlement |
| Services | Codable HTTP, Apple/Google identity, Game Center/GameKit, StoreKit, UMP/GMA, audio, preferences, lifecycle | Gameplay rules or UI layout |
| Design | Stable presentation mapping for themes, cells, pets, typography, spacing | Timing, price, entitlement, hit semantics |

The app composition root injects live, local-fixture, and test implementations.
Services may depend on core value types; core never depends outward.

## State and concurrency

- SwiftUI, SpriteKit, feature controllers, and UI-facing SDK callbacks run on the
  main actor.
- The local `GameCoordinator` owns one synchronous `GameEngine`; it passes input
  directly to the engine before scheduling decoration.
- Network and SDK work use asynchronous service boundaries with screen/match/run
  cancellation. Stale account/session and Multiplayer callbacks are rejected.
- Account and cosmetic mutations are serialized where ordering affects state.
- A background transition freezes gameplay, abandons an issued Arcade run when
  possible, silences audio/haptics, and rejects stale commands.
- No network, file I/O, JSON decoding, advertising, or purchase work is allowed on
  the reaction touch path.

## Timing

Arcade and Zen use one monotonic uptime domain:

1. Create the target before exposure.
2. On the first SpriteKit frame that exposes it, record presentation.
3. Resolve the original compatible `UITouch.timestamp` synchronously.
4. Use an absolute deadline from presentation; exact-deadline input is late.
5. Let one transition win input/expiry and ignore already-resolved input.

`CADisplayLink`/SpriteKit presentation and `UITouch.timestamp` are practical
proxies, not photon-to-contact measurement. Validate both 60 Hz and 120 Hz devices.

Multiplayer v1 currently differs. The coordinator schedules future plans, advances
on an approximately 33 ms tick, queues input behind a fixed 250 ms watermark, and
feeds presentation only after canonical events. All GameKit envelopes currently use
reliable delivery. That architecture explains its visible delay and is the explicit
change target in [MULTIPLAYER_FAST_TASK](MULTIPLAYER_FAST_TASK.md).

## Platform services

- **HTTP:** one cookie-enabled `URLSession`, typed `Codable` requests, CSRF on
  mutations, bounded timeouts, no production fallback.
- **Identity:** Apple and Google provider proofs are exchanged for the PHP session.
  Game Center authenticates independently and supplies a verified secondary link.
- **Game Center publication:** PHP owns allowlisted leaderboard/achievement writes;
  iOS only opens Apple's dashboard.
- **Multiplayer:** PHP owns lobby/manifest/replay/settlement; `GKMatch` owns live
  packets. The client persists only a bounded exact pending transcript submission.
- **StoreKit:** one StoreKit 2 service and purchase controller validate local signed
  transactions, reconcile with PHP, then finish the transaction.
- **Ads:** app-owned UMP/GMA adapters start only after consent and authoritative
  non-ad-free state. The board never knows Google SDK types.
- **Audio/haptics:** one audio controller owns independent Sound FX and Music buses;
  haptics and lifecycle effects remain outside core.
- **Persistence:** `UserDefaults` stores nonsecret preferences/cadence; pending
  Multiplayer settlement uses a bounded application-support file. Durable account
  and economy state stays server-side.

## Multiplayer data flow

```text
PHP lobby + fresh identity proof
        ↓ immutable manifest / seats / colors
GameKit roster → fixed coordinator → canonical compact event stream
        ↓                              ↓
  live peer UI                    identical peer transcripts
                                        ↓
                         PHP replay + matching settlement
```

PHP is never a per-tap relay. Peer aggregates are never authoritative. If exact
stream/evidence recovery fails, cancel or review the match rather than synthesize
proof. Protocol v1 has no coordinator migration.

## Configurations

| Configuration | Current purpose |
| --- | --- |
| Debug | Local development, demo ads, test fixtures |
| Staging | Release-optimized TestFlight, live compatibility backend, owner-split Test-mode ads |
| OwnerAdsQA | Cable-only production-unit/Test-mode diagnostics |
| Release | Disabled ads unless ignored private live configuration is explicitly supplied |

The Staging backend is shared production Season 1 data, not an isolated staging
database. Secrets and private signing/App Store material never belong in Git.
