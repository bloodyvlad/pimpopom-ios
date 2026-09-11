# PimPoPom

PimPoPom is an iPhone-only color-reaction game built with SwiftUI, SpriteKit,
StoreKit 2, Google Mobile Ads, and a pure Swift rules package. Arcade and Zen are
retained; the new 2–4-player Multiplayer v2 is an online, unranked playtest.
Game Center remains a separate account/publication integration.

Build 28 is available to both TestFlight QA groups: power-ups start only on 4×4, Arcade's
clock has a theme-matched rewind arrow, and Multiplayer adds room codes, creator
search and code-only private games. [Current feature contract](docs/BUILD28.md).
Apple approved beta review on 2026-09-11. Multiplayer remains revision 2 with hearts only.

The owner directed the product and accepted each release. Codex and GPT-5.6
supported implementation, tests, asset generation, documentation, and release
automation; generated work was reviewed through the same gates as hand-written
work.

## Current version

| Item | Current truth |
| --- | --- |
| App configuration | iOS 17+, iPhone, Swift 6; `1.02 (28)` |
| TestFlight state | Build 28 VALID; Internal QA and External QA `IN_BETA_TESTING`; beta review `APPROVED` (2026-09-11) |
| Exact uploaded iOS source | `3922867341c43c732e894805f829559140f5b5e4` |
| Hosting | Railway Amsterdam `3041f2bb`, room discovery revision 1; PHP v5 verifier `f84dc921` deployed, schema 024 unchanged |
| Previous supported beta | Build 27 / gameplay revision 2; build 25 uses separate revision-1 rooms |
| Open QA gates | Real-account hosted matches, physical 2/3/4-device/network/latency acceptance; public legal URLs and reviewer access |
| Production App Store | No production release established by this work |
| Backend | `https://speedytapper.otcsoft.com`; server code lives in another repository |

Build 24 is the earlier GameKit/v1 beta; build 25 retains v2 gameplay revision 1
in separate compatible rooms. Build 26 adds Arcade pacing, changing unique colors,
persistent safe-color decoys and shared hearts.
V2 replaces live peer synchronization with a persistent Swift room authority and
reuses the Arcade SpriteKit board. The owner confirmed one identical shared board;
waiting for an own-color opportunity, including on 1×1, is intentional. Numerical
Arcade rules are shared, but cell contention and delivery headroom can extend
personal target spacing. The owner has now authorized Railway EU deployment,
the separate PHP v2 bridge, and TestFlight QA distribution. No paid-plan upgrade
or App Store production submission is authorized. See [current status](docs/CURRENT_VERSION.md).

## Implemented product

- **Arcade:** endless three-life play with progressive boards, decoys, reaction
  ratings, streak multipliers, heart/clock pickups, protocol-verified ranking,
  coins, and achievements.
- **Zen:** endless local practice with no lives, deadline, decoys, ranking, coins,
  achievements, or durable result.
- **Multiplayer v2 playtest:** 2–4 signed-in, confirmed-name players on one shared
  progressive board; own-color targets, independent scores/lives, socket-owned
  rooms and Ready/Start, and no Game Center prerequisite. Unranked, no coins,
  achievements or v2 Game Center publication. Historical v1 leaderboard reads remain.
- **Identity:** Sign in with Apple and Google map to one internal profile; Game
  Center is a verified secondary link and never authenticates a wallet.
- **Economy:** the server owns coins, achievements, catalogs, purchases, and
  cosmetics. StoreKit-signed transactions are reconciled before value is shown.
- **Ads:** UMP-gated AdMob with demo/test routing in committed builds and
  server-authoritative ad-free state. Checked-in Release advertising is disabled.
- **Presentation:** Default, Disco, Light, and Pixel themes; selectable icons;
  pets; independent Sound FX, music, haptics, and glyph settings.

The [v2 implementation brief](docs/MULTIPLAYER_V2_REBUILD.md) describes current
behavior and remaining gates. [Hosting options](docs/MULTIPLAYER_V2_HOSTING.md)
remain background research; Railway Amsterdam is now deployed and boundary-tested.
See the [deployment record](Server/DEPLOYMENT_RAILWAY.md). The old FAST design is superseded.

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

For v2, use the current slice, v2 brief, shared `MP2*` source,
and [service contract](Server/README.md). Older v1 gameplay/API/release sections
describe the retained beta/backend baseline, not proof of v2 deployment.

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
| Local Multiplayer v2 rules and integration | [MULTIPLAYER_V2_REBUILD](docs/MULTIPLAYER_V2_REBUILD.md) |
| Hosting decision, prices and lifecycle caveats | [MULTIPLAYER_V2_HOSTING](docs/MULTIPLAYER_V2_HOSTING.md) |
| Historical FAST pointer | [MULTIPLAYER_FAST_TASK](docs/MULTIPLAYER_FAST_TASK.md) |
| Current visual evidence | [DESIGN_QA](docs/DESIGN_QA.md) |
| Asset provenance | `assets/**/SOURCES.md` |
| Privacy and security summaries | [PRIVACY](PRIVACY.md), [SECURITY](SECURITY.md) |

Superseded plans, contracts, decision chronology, and release notes are available
from Git history, not duplicated in the current working tree.

## Repository boundaries

This repository owns the native client, pure Swift rules, the separate `Server/`
Vapor package, tests, resources, and iOS compatibility contracts. It does not own
or contain the PHP implementation.
Backend changes require a separate reviewed task in the backend repository; an
iOS task must never edit, restore, stage, commit, or deploy that repository.

Code and release contents are proven by an exact Git commit. A TestFlight build
is not an App Store production release, Simulator evidence is not physical-device
validation, and a protocol-verified result is not human-verified or bot-proof.
