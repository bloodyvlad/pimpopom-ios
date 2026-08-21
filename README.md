# PimPoPom

PimPoPom is an iPhone-only color-reaction game built with SwiftUI, SpriteKit,
GameKit, StoreKit 2, Google Mobile Ads, and a pure Swift rules package. Arcade,
Zen, and a 2–4-player Multiplayer beta are implemented.

The owner directed the product and accepted each release. Codex and GPT-5.6
supported implementation, tests, asset generation, documentation, and release
automation; generated work was reviewed through the same gates as hand-written
work.

## Current version

| Item | Current truth |
| --- | --- |
| App configuration | iOS 17+, iPhone, Swift 6, `1.02 (24)` candidate |
| Current TestFlight | Build 22; valid, Internal QA only; known unstable Multiplayer recovery |
| Candidate | Build 24 source; TestFlight upload not authorized |
| Rollback beta | Build 20 from `69fe7422719dd4953e90354a2ae3f3c976995db7` |
| Open release gate | Physical 2/3/4-device, reconnect, and 60/120 Hz acceptance |
| Production App Store | Not released |
| Backend | `https://speedytapper.otcsoft.com`; server code lives in another repository |

Build 24 keeps immediate local feedback and makes ordinary late input non-fatal:
ordinary gaps stay interactive, `Catching up` appears only after one second, and
recovery has a 15-second ceiling. Start, pause, Resume, Finish, cancel, evidence,
and snapshots are retained or retried without changing PHP transcript/proof v1.
Resume advances after its reliable send reaches every intended peer; exact ACK
recovery continues in the background.
It is a tested source candidate, not a TestFlight deployment. See
[the current slice](docs/CURRENT_VERSION.md).

## Implemented product

- **Arcade:** endless three-life play with progressive boards, decoys, reaction
  ratings, streak multipliers, protocol-verified ranking, coins, and achievements.
- **Zen:** endless local practice with no lives, deadline, decoys, ranking, coins,
  achievements, or durable result.
- **Multiplayer beta:** 2–4 signed-in players, own-color targets, GameKit live
  traffic, PHP lobby/manifest/replay/settlement, no coins or achievements, and
  protocol-verified peer-consistent results.
- **Identity:** Sign in with Apple and Google map to one internal profile; Game
  Center is a verified secondary link and never authenticates a wallet.
- **Economy:** the server owns coins, achievements, catalogs, purchases, and
  cosmetics. StoreKit-signed transactions are reconciled before value is shown.
- **Ads:** UMP-gated AdMob with demo/test routing in committed builds and
  server-authoritative ad-free state. Checked-in Release advertising is disabled.
- **Presentation:** Default, Disco, Light, and Pixel themes; selectable icons;
  pets; independent Sound FX, music, haptics, and glyph settings.

The current [FAST Multiplayer slice](docs/MULTIPLAYER_FAST_TASK.md) is implemented
in build 24. PHP compatibility remains v1; host migration, custom LAN routing, and
concurrent per-seat targets remain deferred.

## Build and test

Requirements: Xcode 26.2 or newer and XcodeGen 2.45.4.

```sh
brew install xcodegen
Scripts/create-alpha-simulators.sh
Scripts/check.sh
```

Open `PimPoPom.xcodeproj`, select an Apple development team, and run an iPhone
target. `project.yml` is the project source; regenerate rather than hand-editing
generated project structure.

Google sign-in needs matching ignored local OAuth configuration. The Debug
**PimPoPom StoreKit Local** scheme uses the committed StoreKit catalog and an
offline credit fixture. **PimPoPom Owner Ads QA** is the explicit cable-only
production-unit/Test-mode lane. Never click a production-unit creative unless it
visibly says **Test mode**.

## Documentation

| Concern | Current source |
| --- | --- |
| Version, release state, and known gaps | [CURRENT_VERSION](docs/CURRENT_VERSION.md) |
| Binding product/technical choices | [DECISIONS](docs/DECISIONS.md) |
| Dependency and concurrency boundaries | [ARCHITECTURE](docs/ARCHITECTURE.md) |
| Gameplay rules | [GAMEPLAY_SPEC](docs/GAMEPLAY_SPEC.md) |
| Deployed iOS/backend compatibility | [API_CONTRACT](docs/API_CONTRACT.md) |
| Ads, StoreKit, economy, and privacy | [MONETIZATION_AND_PRIVACY](docs/MONETIZATION_AND_PRIVACY.md) |
| Automated and physical quality gates | [TESTING](docs/TESTING.md) |
| TestFlight/App Store release process | [RELEASE](docs/RELEASE.md) |
| Approved Multiplayer latency work | [MULTIPLAYER_FAST_TASK](docs/MULTIPLAYER_FAST_TASK.md) |
| Current visual evidence | [DESIGN_QA](docs/DESIGN_QA.md) |
| Asset provenance | `assets/**/SOURCES.md` |
| Privacy and security summaries | [PRIVACY](PRIVACY.md), [SECURITY](SECURITY.md) |

Superseded plans, contracts, decision chronology, and release notes are available
from Git history, not duplicated in the current working tree.

## Repository boundaries

This repository owns the native client, pure Swift rules, tests, resources, and
iOS compatibility contracts. It does not own or contain the PHP implementation.
Backend changes require a separate reviewed task in the backend repository; an
iOS task must never edit, restore, stage, commit, or deploy that repository.

Code and release contents are proven by an exact Git commit. A TestFlight build
is not an App Store production release, Simulator evidence is not physical-device
validation, and a protocol-verified result is not human-verified or bot-proof.
