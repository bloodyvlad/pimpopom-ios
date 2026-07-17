# PimPoPom

PimPoPom is the native iOS edition of a fast color-reaction game. **PimPoPom** is the product name in the app, App Store metadata, icons, audio branding, analytics, support material, and player-facing copy.

This repository is intentionally independent from the legacy web implementation. It now contains a playable native Arcade/Zen alpha, a pure Swift rules engine, SpriteKit rendering, SwiftUI app surfaces, and an internal integration with the existing Hostinger PHP service.

## Migration baseline

- Behavioral source reviewed: legacy web repository commit `675551adc715942ce2512c14d396d5d14e763f02` on 2026-07-14.
- That commit is a migration baseline, not evidence of what is currently deployed.
- The current PHP client contract and visual behavior were most recently audited at legacy repository `main` commit `209ee6ca84b17bc81144d2dc60c613feeae05dc0` on 2026-07-17. Live probes confirmed Hostinger Season 1 and deployed build ID `20260715-1`; they did not prove the deployed Git commit.
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
- Hostinger integration: live public session/leaderboard reads plus existing profile, nickname, Google token exchange, and ranked start/abandon/finish paths. Eligible signed-in Arcade runs automatically obtain a ticket and submit their proof at Game Over; ranked play activates only after Google sign-in and nickname confirmation, while anonymous and Zen play never create a ranked result.
- Shared economy/cosmetics: live theme and pet catalogs, server-confirmed coin balance, atomic signed-in buy/select/hide/show mutations, free signed-out Default/Disco selection, and server-derived special-pet presentation.
- Visual parity: the fixed, non-scrolling native main menu, darker-green Pim wordmark, illuminated intro/slogan treatments, Arcade/Zen controls, feature hierarchy, backgrounds, two-column Theme Shop, detailed Leaderboard/Profile/results surfaces, custom gameplay header/HUD, near-full-width board, centered announcements, border reaction stamps, and Speed streak/multiplier translate the reviewed web design into SwiftUI and SpriteKit. The opaque web coin art and black-bordered coin/rank badges are shared across native surfaces and sit on the expected button corners; the menu trophy shows the signed-in player's Arcade position. Live cells, Theme Shop screenshots, and Your Color use one canonical glyph box so circles, triangles, squares, diamonds, crosses, and stars occupy the same visual bounds. Classic remains clean, Light adds a crystal/glass surface, Pixel adds clipped faint grain and true pixel paths, and Disco combines its retained concrete/scratch textures with vivid saturated backlit targets, silver borders, and a 40%-darker uneven inactive tile. Pixel uses the reviewed Jersey 10 font at a native 25% scale increase. Light also keeps its sky gradient, logo readability plate, and transparent SpriteKit scene exposing the white rounded board shell. The Achievements entry is present but its catalog/claim sheet remains an explicit placeholder.
- Themes and pets: all four theme palettes plus reviewed current Foka/Kesha/Tauta/Misha/Mitsuri sprite sheets, server-derived Muse special-pet art, and the owner-approved native Pancake replacement with a glowing blue floor are native resources. A theme is selected or bought by tapping its whole tile; each preview is a stable candidate-theme game screenshot whose pixels do not depend on the currently selected theme and uses the same glyph/material renderer as the live board. Placement is surface-specific and shop previews stay static until tapped. Shop, menu, and gameplay share one horizontal facing resolver: near-exact horizontal alignment is front, the first 15% of the interaction width on either side is half-turned, and farther taps are fully turned. Every gameplay-board touch, including a visual gap between cells, may orient the pet without changing whether the engine accepts a cell action. Turns proceed from the currently displayed pose through adjacent directional frames without returning to center first. Menu pets sleep after inactivity, the active menu pet is shifted left, and the gameplay pet sits at 40% of screen width. Pancake is fifteen points lower relative to its floor on the menu and Leaderboard only, and its clean full-right sprite is mirrored for full-left; gameplay and Pet Shop placement are unchanged by this adjustment. Pancake uses the normal 500-coin server purchase path; the client does not invent ownership or price.
- Audio: four migrated menu/gameplay/tap suites, the shared life-loss cue, independent persistent Music/Sound FX controls, deterministic gameplay-start and terminal-silence routing, and an original rising Pim–Po–Pom activation-cue candidate. Assets, masters, and deterministic generators are retained and hash-checked.
- Google: package integrated and server audience configured; real iOS/reversed client values are supplied only through ignored `Config/Local.xcconfig`, while committed examples remain placeholders.
- Ads/StoreKit: disabled placeholders. The bottom ad host remains below the Speed streak meter. Lower-right Remove Ads, Theme Shop Buy Coins, and Pet Shop Buy Coins each open an explicit StoreKit placeholder that grants no value or entitlement.
- Game Center: the Profile screen contains an explicit non-connecting internal-alpha placeholder. The Hostinger leaderboard remains authoritative; no GameKit entitlement, identity binding, or score mirror is enabled.
- Device evidence: implementation commit `d3ffd87` was development-signed, installed, and launched successfully through CoreDevice on the owner's wired iPhone SE (3rd generation) on iOS 26.3. Per owner request, no automated or structured visual/touch/listening retest was run for that checkpoint. Earlier install checkpoints remain recorded in `docs/DESIGN_QA.md`; the 13 mini/13 Pro remain Simulator-only.
- Simulator regression evidence: implementation commit `a607adc` passed 29 core checks, 50 native unit tests, and all 18 XCUITest paths on the named iPhone SE 2022 Simulator with iOS 26.5. Direct SE inspection covered the opaque corner coin badge; vivid active Disco target; Light crystal treatment; Pixel grain, pixel glyph, and matching Your Color preview; and Pancake's menu/Leaderboard placement plus clean left/right menu following. The earlier 13 mini/13 Pro regression remains recorded at commit `ec71d21` and was not rerun for this batch. The current checkpoint was not installed or tested on physical hardware.
- Remote repository, final signing identity, backend-native API, final logo/launch-cue acceptance, StoreKit products, and ad account are not created yet.
- No production deployment or App Store submission has occurred.
