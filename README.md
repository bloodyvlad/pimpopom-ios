# PimPoPom

PimPoPom is an iPhone-only color-reaction game built with SwiftUI, SpriteKit,
StoreKit 2, Google Mobile Ads, and a pure Swift rules package. Arcade and Zen are
retained alongside 2–4-player online Multiplayer v2. Game Center remains a
separate account/publication integration.

This branch prepares **1.02 (33)** to open directly to the main menu without a
manual age selector or optional Apple sharing prompts. Required regional Apple
checks remain. Unknown age uses unspecified advertising treatment without storing
an invented age. Purchases use the ordinary StoreKit flow. Legal links are only
in main-menu Settings, and the Multiplayer group icon is restored.
Build 32 was withdrawn from public review after physical-device onboarding
failures. Only age/consent checks are authorized for this correction; public review
remains withdrawn. See [onboarding correction](docs/ONBOARDING_AGE_FIX.md).

The following build-32 preparation record is historical.

Build 32 added Apple Declared Age Range and read-only
Apple-supplied ages, retaining the 13+ policy and three-game ad cadence. The owner
authorized TestFlight upload and submission of the same build for public App Store
review. Physical/manual QA is deferred, and only age/consent tests are requested.
Build 30 is the last uploaded build verified before preparation; build 31 remains
local only. Exact build32 archive/upload evidence is recorded separately after it
happens. See [build32 scope](docs/PRODUCTION_CANDIDATE_32.md).
Checked-in Release ads remain disabled; authorized archives use an ignored private
override with verified production units and no QA identifiers.

The following build-29 release record is historical context.

Build 29 adds score-ranked Multiplayer, two coins per eligible connected/alive
minute, guided practice, lobby privacy editing and themed gameplay feedback.
See [build-29 rules and QA limitations](docs/MP29_GAMEPLAY_TUTORIALS.md).
PHP migration 025 and Railway deployment are verified. Build 29 is approved and
available to the existing Internal QA and External QA TestFlight groups.

The owner directed the product and accepted each release. Codex and GPT-5.6
supported implementation, tests, asset generation, documentation, and release
automation. Per-release verification, failures and owner-authorized exceptions
are recorded explicitly.

## Historical build-29 version

| Item | Current truth |
| --- | --- |
| App configuration | iOS 17+, iPhone, Swift 6; `1.02 (29)` |
| TestFlight state | Build 29 VALID; review APPROVED; both QA groups IN_BETA_TESTING (2026-09-11 19:02:18 UTC) |
| Exact uploaded iOS source | `199bf48f6dccbc0b1a3b234dc12aca3977c16a50` |
| Hosting | Railway Amsterdam `9ec61784`, gameplay revision 3 / discovery 2; PHP `bf0ef1b` verified, schema 025 |
| Previous supported beta | Build 28 / gameplay revision 2; build 25 uses separate revision-1 rooms |
| Open QA gates | Final tutorial/stamp UI checks; real-account rewards and hosted matches; physical/network/accessibility acceptance; legal/reviewer readiness |
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

## Build-29 product

- **Arcade:** endless three-life play with progressive boards, decoys, reaction
  ratings, streak multipliers, heart/clock pickups, protocol-verified ranking,
  coins, and achievements.
- **Zen:** endless local practice with no lives, deadline, decoys, ranking, coins,
  achievements, or durable result.
- **Multiplayer v2 playtest:** 2–4 signed-in, confirmed-name players on one shared
  progressive board; own-color targets, independent scores/lives, socket-owned
  rooms and Ready/Start, and no Game Center prerequisite. Revision 3 continues
  until all players are out; highest final score wins. Eligible completed results
  enter the v2 leaderboard and earn two coins per alive-connected minute. No
  achievements or Game Center publication; older revisions remain unranked/unrewarded.
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
