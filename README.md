# PimPoPom

PimPoPom is the native iOS edition of a fast color-reaction game. **PimPoPom** is the product name in the app, App Store metadata, icons, audio branding, analytics, support material, and player-facing copy.

This repository is intentionally independent from the legacy web implementation. It now contains a playable native Arcade/Zen alpha, a pure Swift rules engine, SpriteKit rendering, SwiftUI app surfaces, and an internal integration with the existing Hostinger PHP service.

## Migration baseline

- Behavioral source reviewed: legacy web repository commit `675551adc715942ce2512c14d396d5d14e763f02` on 2026-07-14.
- That commit is a migration baseline, not evidence of what is currently deployed.
- The current PHP client contract was also audited at legacy repository commit `087cd018900cb5f04a85ace20bc99db05a0b7fbc`. Live probes confirmed Hostinger Season 1 and deployed build ID `20260715-1`; they did not prove the deployed Git commit.
- Copy only reviewed behavior, deterministic fixtures, and assets with documented redistribution rights.
- Do not modify the legacy repository to implement PimPoPom. Backend changes needed by both clients require their own reviewed task in the repository that owns the backend.

## Recommended native stack

- Swift and Swift concurrency with strict concurrency checking.
- SwiftUI for navigation, menus, shops, profile, settings, results, and accessibility-first app surfaces.
- SpriteKit for the latency-sensitive reaction board and visual effects.
- A framework-independent `PimPoPomCore` module for deterministic rules, configuration, injected time/randomness, state transitions, and proof events. Tests use seeded randomness; production does not imply a server seed.
- `AVAudioEngine`/`AVAudioPlayerNode` for preloaded low-latency audio and `Core Haptics` for supported devices.
- `URLSession` with typed `Codable` requests. The internal alpha temporarily reuses the PHP secure cookie plus CSRF contract; a versioned native session remains the external-release direction.
- StoreKit 2 for Remove Ads and coin packs; GameKit may mirror verified scores and achievements but never owns the coin economy.
- An ad SDK only behind an app-owned adapter, consent gate, test configuration, and stable reserved layout.

The app currently uses SwiftUI, SpriteKit, `PimPoPomCore`, `URLSession`, Google Sign-In for iOS, and one app-owned `AVAudioEngine` service. Ads and StoreKit remain disabled placeholders; Google activates only when a real iOS OAuth client ID is supplied through the ignored local configuration.

## Start here

1. Use Xcode 26 or newer and XcodeGen 2.45.4 (`brew install xcodegen`). Swift Package Manager resolves the pinned Google Sign-In dependency.
2. Create the agreed simulator profiles once with `Scripts/create-alpha-simulators.sh`, then generate/build/test everything with `Scripts/check.sh`.
3. Open `PimPoPom.xcodeproj`, select an Apple Team under Signing & Capabilities, select the connected iPhone SE 2022, and Run. Local Arcade/Zen and public leaderboards need no Google setup.
4. To enable Google, create an iOS OAuth client in the same Google Cloud project for bundle ID `com.otcsoft.pimpopom.alpha`, copy `Config/Local.example.xcconfig` to ignored `Config/Local.xcconfig`, and replace its two example values. The existing Web server audience is committed as public build configuration; no client secret belongs in the app.
5. Follow the exact internal-alpha flow and limitations in [`docs/ALPHA_FAST_PATH.md`](docs/ALPHA_FAST_PATH.md).

## Documentation map

| Concern | Source of truth |
| --- | --- |
| Committed repository status and setup | This README |
| Durable accepted and proposed choices | [`docs/DECISIONS.md`](docs/DECISIONS.md) |
| Ordered migration work and exit gates | [`docs/MIGRATION_PLAN.md`](docs/MIGRATION_PLAN.md) |
| Current local-device execution track | [`docs/ALPHA_FAST_PATH.md`](docs/ALPHA_FAST_PATH.md) |
| Dependency direction and module boundaries | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| Rules that native parity must preserve | [`docs/GAMEPLAY_SPEC.md`](docs/GAMEPLAY_SPEC.md) |
| Native API, identity, and server responsibilities | [`docs/API_CONTRACT.md`](docs/API_CONTRACT.md) |
| Ads, purchases, coin accounting, and privacy | [`docs/MONETIZATION_AND_PRIVACY.md`](docs/MONETIZATION_AND_PRIVACY.md) |
| Test matrix and quality gates | [`docs/TESTING.md`](docs/TESTING.md) |
| Signing, TestFlight, App Store, and rollback | [`docs/RELEASE.md`](docs/RELEASE.md) |
| Unresolved product and platform choices | [`docs/OPEN_QUESTIONS.md`](docs/OPEN_QUESTIONS.md) |
| Visual review history | [`docs/DESIGN_QA.md`](docs/DESIGN_QA.md) |
| Branding, audio, pet, font, and theme source records | [`assets/branding/SOURCES.md`](assets/branding/SOURCES.md), [`assets/audio/SOURCES.md`](assets/audio/SOURCES.md), [`assets/pets/SOURCES.md`](assets/pets/SOURCES.md), [`assets/fonts/SOURCES.md`](assets/fonts/SOURCES.md), [`assets/themes/SOURCES.md`](assets/themes/SOURCES.md) |
| Privacy engineering status and security rules | [`PRIVACY.md`](PRIVACY.md), [`SECURITY.md`](SECURITY.md), [`AGENTS.md`](AGENTS.md) |
| Contribution and change history | [`CONTRIBUTING.md`](CONTRIBUTING.md), [`CHANGELOG.md`](CHANGELOG.md) |
| Licence and third-party notices | [`LICENSE.md`](LICENSE.md), [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) |

## Repository shape

```text
PimPoPom/
├── PimPoPom.xcodeproj
├── project.yml             # Reproducible XcodeGen source
├── App/                     # SwiftUI, SpriteKit gameplay, API and identity client
├── Packages/
│   └── PimPoPomCore/        # Pure deterministic rules and tests
├── Config/                  # Committed examples; local secrets ignored
├── Tests/                   # Native unit and UI smoke tests
├── Scripts/                 # Reproducible checks and asset validation
├── assets/                  # Reviewed runtime assets and retained masters
└── docs/
```

## Current status

- Separate local Git repository: created.
- Product name: accepted as PimPoPom.
- Native migration documentation: bootstrapped.
- Xcode project: generated reproducibly for local signing with development bundle ID `com.otcsoft.pimpopom.alpha`.
- Arcade and Zen: playable through a native deterministic engine and SpriteKit board, including lives/recovery, difficulty phases, decoys, scoring, ratings, multipliers, proof events, Zen cadence, results, restart, and lifecycle abandonment.
- Hostinger integration: live public session/leaderboard reads plus existing profile, nickname, Google token exchange, ranked start/abandon/finish paths. Ranked play activates only after Google sign-in and nickname confirmation.
- Shared economy/cosmetics: live theme and pet catalogs, server-confirmed coin balance, atomic signed-in buy/select/hide/show mutations, free signed-out Default/Disco selection, and server-derived special-pet presentation.
- Visual parity: the fixed, non-scrolling native main menu, wordmark, Arcade/Zen controls, feature hierarchy, backgrounds, two-column Theme Shop, custom gameplay header/HUD, near-full-width board, and Speed streak/multiplier translate the reviewed web design into SwiftUI and SpriteKit. Classic, Light, and Pixel effects are code-native; Pixel uses the reviewed Jersey 10 font at a native 10% scale increase and Disco uses the exact reviewed texture set. Light uses a clean sky gradient with no capsule “cloud” artifacts, and its transparent SpriteKit scene exposes the white rounded board shell. The Achievements entry is present but its catalog/claim sheet remains an explicit placeholder.
- Themes and pets: all four theme palettes plus reviewed current Foka/Kesha/Tauta/Misha/Mitsuri sprite sheets and server-derived Muse special-pet art are native resources. Menu/gameplay placement and Pet Shop habitat/static-preview behavior follow parent web commit `7582b2d`; pets sleep after menu inactivity, wake/turn toward taps, and the gameplay pet sits at 40% of screen width. Pancake remains a labelled code-native placeholder and cannot be newly purchased until replacement art is approved.
- Audio: four migrated menu/gameplay/tap suites, the shared life-loss cue, independent persistent Music/Sound FX controls, deterministic gameplay-start and terminal-silence routing, and an original rising Pim–Po–Pom activation-cue candidate. Assets, masters, and deterministic generators are retained and hash-checked.
- Google: package integrated and server audience configured; real iOS/reversed client values are supplied only through ignored `Config/Local.xcconfig`, while committed examples remain placeholders.
- Ads/StoreKit: disabled placeholders. The bottom ad host remains below the Speed streak meter. Lower-right Remove Ads, Theme Shop Buy Coins, and Pet Shop Buy Coins each open an explicit StoreKit placeholder that grants no value or entitlement.
- Device evidence: the gameplay/icon checkpoint `fd34cf4` was development-signed, installed, launched, trusted, and confirmed working on the owner's iPhone SE (3rd generation) on iOS 26.3. The cosmetics/audio checkpoint `54bd372` was then development-signed and installed on the same device; automatic launch was denied because the phone was locked, so launch, listening, and touch review of that slice remain open. The 13 mini/13 Pro remain Simulator-only.
- Simulator regression evidence: implementation commit `ec71d21` passed 29 core tests, 33 native unit tests, and all 16 iPhone SE 2022 XCUITest paths on iOS 26.5. The 33 native tests plus 15 device-independent UI paths also passed separately on iPhone 13 mini and iPhone 13 Pro. Retained captures cover fixed Light/Pixel menus and the transparent Light gameplay shell. This checkpoint was not installed or tested on physical hardware.
- Remote repository, final signing identity, backend-native API, final logo/launch-cue acceptance, StoreKit products, and ad account are not created yet.
- No production deployment or App Store submission has occurred.
