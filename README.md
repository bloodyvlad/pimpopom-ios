# PimPoPom

PimPoPom is the native iOS edition of a fast color-reaction game. **PimPoPom** is the product name in the app, App Store metadata, icons, audio branding, analytics, support material, and player-facing copy.

This repository is intentionally independent from the legacy web implementation. It currently contains the reviewed product, architecture, migration, security, testing, and release plan; the Xcode project has not been scaffolded yet.

## Migration baseline

- Behavioral source reviewed: legacy web repository commit `675551adc715942ce2512c14d396d5d14e763f02` on 2026-07-14.
- That commit is a migration baseline, not evidence of what is currently deployed.
- Copy only reviewed behavior, deterministic fixtures, and assets with documented redistribution rights.
- Do not modify the legacy repository to implement PimPoPom. Backend changes needed by both clients require their own reviewed task in the repository that owns the backend.

## Recommended native stack

- Swift and Swift concurrency with strict concurrency checking.
- SwiftUI for navigation, menus, shops, profile, settings, results, and accessibility-first app surfaces.
- SpriteKit for the latency-sensitive reaction board and visual effects.
- A framework-independent `PimPoPomCore` module for deterministic rules, configuration, injected time/randomness, state transitions, and proof events. Tests use seeded randomness; production does not imply a server seed.
- `AVAudioEngine`/`AVAudioPlayerNode` for preloaded low-latency audio and `Core Haptics` for supported devices.
- `URLSession` with typed `Codable` requests, Keychain-held session material, and a versioned native API contract.
- StoreKit 2 for Remove Ads and coin packs; GameKit may mirror verified scores and achievements but never owns the coin economy.
- An ad SDK only behind an app-owned adapter, consent gate, test configuration, and stable reserved layout.

These choices are recorded as proposed until the bootstrap phase accepts the deployment target, backend contract, ad vendor, and monetization accounting.

## Start here

1. Complete **Phase 0 — Owner setup** at the very beginning of [`docs/MIGRATION_PLAN.md`](docs/MIGRATION_PLAN.md).
2. Resolve the release-blocking items in [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md).
3. Accept or revise the proposed records in [`docs/DECISIONS.md`](docs/DECISIONS.md).
4. Scaffold the Xcode workspace only after bundle identifiers, signing ownership, deployment targets, and configuration names are known.

## Documentation map

| Concern | Source of truth |
| --- | --- |
| Committed repository status and setup | This README |
| Durable accepted and proposed choices | [`docs/DECISIONS.md`](docs/DECISIONS.md) |
| Ordered migration work and exit gates | [`docs/MIGRATION_PLAN.md`](docs/MIGRATION_PLAN.md) |
| Dependency direction and module boundaries | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| Rules that native parity must preserve | [`docs/GAMEPLAY_SPEC.md`](docs/GAMEPLAY_SPEC.md) |
| Native API, identity, and server responsibilities | [`docs/API_CONTRACT.md`](docs/API_CONTRACT.md) |
| Ads, purchases, coin accounting, and privacy | [`docs/MONETIZATION_AND_PRIVACY.md`](docs/MONETIZATION_AND_PRIVACY.md) |
| Test matrix and quality gates | [`docs/TESTING.md`](docs/TESTING.md) |
| Signing, TestFlight, App Store, and rollback | [`docs/RELEASE.md`](docs/RELEASE.md) |
| Unresolved product and platform choices | [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md) |
| Visual review history | [`docs/DESIGN_QA.md`](docs/DESIGN_QA.md) |
| Branding and audio source records | [`assets/branding/SOURCES.md`](assets/branding/SOURCES.md), [`assets/audio/SOURCES.md`](assets/audio/SOURCES.md) |
| Privacy engineering status and security rules | [`PRIVACY.md`](PRIVACY.md), [`SECURITY.md`](SECURITY.md), [`AGENTS.md`](AGENTS.md) |
| Contribution and change history | [`CONTRIBUTING.md`](CONTRIBUTING.md), [`CHANGELOG.md`](CHANGELOG.md) |
| Licence and third-party notices | [`LICENSE.md`](LICENSE.md), [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) |

## Planned repository shape

```text
PimPoPom/
├── PimPoPom.xcworkspace
├── App/                     # SwiftUI entry point and composition root
├── Packages/
│   ├── PimPoPomCore/        # Pure deterministic rules
│   ├── PimPoPomContracts/   # Service-facing protocols and shared models
│   ├── PimPoPomGameplay/    # SpriteKit scene and touch/presentation bridge
│   ├── PimPoPomFeatures/    # Menus, shops, settings, profile, results
│   ├── PimPoPomServices/    # API, auth, purchases, ads, audio, haptics
│   └── PimPoPomDesign/      # Theme tokens and reusable presentation
├── Config/                  # Committed examples; local secrets ignored
├── Tests/                   # Unit, parity, UI, snapshot, integration fixtures
├── Scripts/                 # Reproducible checks and asset validation
├── assets/                  # Reviewed runtime assets and retained masters
└── docs/
```

## Current status

- Separate local Git repository: created.
- Product name: accepted as PimPoPom.
- Native migration documentation: bootstrapped.
- Xcode project, app code, remote repository, signing, backend changes, StoreKit products, ad account, generated logo, and launch sting: not created yet.
- No production deployment or App Store submission has occurred.
