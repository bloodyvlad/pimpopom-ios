# PimPoPom

PimPoPom is the native iOS edition of a fast color-reaction game. **PimPoPom** is the product name in the app, App Store metadata, icons, audio branding, analytics, support material, and player-facing copy.

This repository is intentionally independent from the legacy web implementation. It now contains a playable native Arcade/Zen alpha, a pure Swift rules engine, SpriteKit rendering, SwiftUI app surfaces, and an internal integration with the existing Hostinger PHP service.

## Migration baseline

- Behavioral source reviewed: legacy web repository commit `675551adc715942ce2512c14d396d5d14e763f02` on 2026-07-14.
- That commit is a migration baseline, not evidence of what is currently deployed.
- The current PHP client contract was most recently audited at legacy repository release commit `2173263dc57cdedb50b2c3f2c560744979a74809` on 2026-07-19. Live HTML, health, and signed-out session probes confirmed Hostinger Season 1, deployed build ID `20260719-2`, and the wallet/ad-free/StoreKit response shape, matching retained annotated deployment tag `hostinger-20260719-2`. That release explicitly retains the native client's `20260719-1` ranked-proof compatibility window; this still does not prove an unrecorded future deployment.
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

The app currently uses SwiftUI, SpriteKit, `PimPoPomCore`, `URLSession`, Google Sign-In for iOS, GameKit, StoreKit 2, and one app-owned `AVAudioEngine` service. Ads remain a disabled placeholder. StoreKit uses a server-authoritative wallet/entitlement bridge and a Debug-only offline configuration; real value still requires Sandbox/TestFlight validation. Google activates only when a real iOS OAuth client ID is supplied through the ignored local configuration.

## Start here

1. Use Xcode 26 or newer and XcodeGen 2.45.4 (`brew install xcodegen`). Swift Package Manager resolves the pinned Google Sign-In dependency.
2. Create the agreed simulator profiles once with `Scripts/create-alpha-simulators.sh`, then generate/build/test everything with `Scripts/check.sh`.
3. Open `PimPoPom.xcodeproj`, select an Apple Team under Signing & Capabilities, select the connected iPhone SE 2022, and Run. Local Arcade/Zen and public leaderboards need no Google setup.
4. To enable Google, create an iOS OAuth client in the same Google Cloud project for bundle ID `com.otcsoftware.pimpopom`, copy `Config/Local.example.xcconfig` to ignored `Config/Local.xcconfig`, and replace its two example values. The existing Web server audience is committed as public build configuration; no client secret belongs in the app. An older iOS client registered for `com.otcsoft.pimpopom.alpha` does not match this app.
5. For deterministic local purchase testing, run the **PimPoPom StoreKit Local** Debug scheme. It uses the committed `.storekit` catalog plus a clearly isolated in-memory credit fixture and never sends local test transactions to Hostinger.
6. Follow the exact internal-alpha flow and limitations in [`docs/ALPHA_FAST_PATH.md`](docs/ALPHA_FAST_PATH.md).

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
- Xcode project: generated reproducibly for Debug, release-optimized Staging, and Release signing with bundle ID `com.otcsoftware.pimpopom`.
- Arcade and Zen: playable through a native deterministic engine and SpriteKit board, including lives/recovery, difficulty phases, decoys, scoring, ratings, multipliers, proof events, Zen cadence, results, restart, and lifecycle abandonment.
- Hostinger integration: live public session/leaderboard/achievement reads plus existing profile, nickname, Google token exchange, ranked start/abandon/finish, authenticated achievement claims, StoreKit credit, and account deletion. Eligible signed-in Arcade runs use the server-retained `20260719-1` native compatibility gate on deployed release `20260719-2`, must obtain a PHP ticket before play, and submit their chronological proof at Game Over. A verified finish must echo the exact run UUID as `submittedEntryId`; review/quarantine outcomes remain saved but are described as withheld. The result screen confirms a successful save, while a PHP session-bootstrap failure—or a ranked-ticket failure for an eligible signed-in player—blocks play instead of silently creating an unsaved game. Anonymous and Zen play never create a ranked result.
- Shared economy/cosmetics: live theme, pet, and five-goal achievement catalogs; server-confirmed coin balance; atomic signed-in buy/select/hide/show and idempotent reward-claim mutations; free signed-out Default/Disco selection; and server-derived special-pet presentation. The themed Achievements screen shows progress plus locked, ready, and claimed server states without repeating the current wallet balance, while the menu marks rewards ready to collect. The PHP service remains the sole authority for unlocks, rewards, ownership, and balance.
- App icons: ImageGen Glow is the primary, with Light glass and Pixel alternates. All three spell the name on progressively indented `Pim`, `Po`, and `Pom` lines; the retired black-outline icon is no longer bundled. Settings exposes whole-tile choices through iOS's native alternate-icon API, and the Home Screen context menu's **Change Icon** quick action follows `pimpopom://settings/icon` directly to that selector. iOS owns icon persistence and confirmation. Sources, masters, prompts, previews, and hashes are retained separately; physical Home Screen/context-menu review and final acceptance remain pending.
- Visual parity: the fixed, non-scrolling native main menu, darker-green Pim wordmark, illuminated intro/slogan treatments, Arcade/Zen controls, feature hierarchy, backgrounds, two-column Theme Shop, detailed Leaderboard/Profile/results surfaces, custom gameplay header/HUD, near-full-width board, centered announcements, and Speed Bar/multiplier translate the reviewed web design into SwiftUI and SpriteKit. The first three rule stamps return once per cold app launch, sit 10 points farther right, and yield to rotating slogans placed 10 points farther left after that launch's first completed Arcade or Zen game. Leaderboard rows reserve a right-aligned score column and omit the obsolete Legacy badge. Early/empty and wrong-cell mistakes share a centered yellow **Missed** stamp, late expiry remains **Too slow**, and reaction feedback renders above every board refresh. Every accepted hit shows one upright, borderless two-line presentation at the exact tap: `+N points` in the larger type and `Perfect • 270ms` beneath it in smaller type. The grouped copy stays local and fades completely within 980 milliseconds without traveling into the HUD or Speed Bar. The Zen Your Color preview is a normal 40-point horizontal gradient using the logo color sequence, and both Arcade hearts and Zen infinity use semantic red `#ff5370`. The Arcade Your Color panel uses its actual cell color for the four-point outline and stronger outward glow, including in Light. The opaque web coin art and black-bordered coin/rank badges are shared across native surfaces and sit on the expected button corners; the menu trophy shows the signed-in player's Arcade position. Live cells, Theme Shop screenshots, and Your Color use one equal-bounds code-native glyph geometry: the retained reduced box stays 1× on a one-cell board and uses 2× on both 2×2 and 4×4/16-cell boards; Theme Shop and Your Color previews use the same 2× multiplier. Classic remains clean, Light adds a crystal/glass surface, Pixel adds clipped deterministic brighter square grain and true pixel paths, and Disco combines visible black concrete/reflected-light backing, near-black inactive tiles, retained scratch/glaze texture, mixed silver borders, 22/15/11-point live radii, no square cell underlays, and a cached transparent-center additive halo above active cells and below feedback. Pixel uses the reviewed Jersey 10 font at a native 25% scale increase. Light also keeps its sky gradient, logo readability plate, and transparent SpriteKit scene exposing the white rounded board shell.
- Themes and pets: all four theme palettes plus reviewed current Foka/Kesha/Tauta/Misha/Mitsuri sprite sheets, server-derived Muse special-pet art, and the owner-approved native Pancake replacement with a glowing blue floor are native resources. A theme is selected or bought by tapping its whole tile; each preview is a stable candidate-theme game screenshot whose pixels do not depend on the currently selected theme and uses the same glyph/material renderer as the live board. Placement is surface-specific and shop previews stay static until tapped. Shop, menu, and gameplay share one horizontal facing resolver: near-exact horizontal alignment is front, the first 15% of the interaction width on either side is half-turned, and farther taps are fully turned. Every gameplay-board touch may orient the pet. A touch between cells is also mapped to a valid non-target/empty engine action and produces a protocol-valid **Missed** result; only the outer 12-point shell padding remains ignored. Turns proceed from the currently displayed pose through adjacent directional frames without returning to center first. Foka's clean left and half-left source cells are mirrored for the corresponding right poses, avoiding the mismatched authored right-side frames without changing any other pet. Menu pets sleep after inactivity; their reviewed left-shifted placement is nudged 10 points back to the right, while the gameplay pet remains at 40% of screen width. Pancake is fifteen points lower relative to its floor on the menu and Leaderboard only, and its clean full-right sprite is mirrored for full-left; gameplay and Pet Shop placement are unchanged by this adjustment. Pancake uses the normal 500-coin server purchase path; the client does not invent ownership or price.
- Audio: four migrated menu/gameplay/tap suites, the shared life-loss cue, independent persistent Music/Sound FX controls, deterministic gameplay-start and terminal-silence routing, and an original rising Pim–Po–Pom activation-cue candidate. Assets, masters, and deterministic generators are retained and hash-checked.
- Google: package integrated and server audience configured; real iOS/reversed client values are supplied only through ignored `Config/Local.xcconfig`, while committed examples remain placeholders.
- Ads/StoreKit: ads remain a disabled placeholder, and the reserved 50-point banner host remains below the lifted pet/Speed Bar footer without shrinking the near-full-width board. Lower-right Remove Ads, Theme Shop Buy Coins, and Pet Shop Buy Coins share the real StoreKit 2 sheet. It loads localized App Store products, requires a signed-in server-bound PimPoPom profile, submits only the verified JWS and server-issued `appAccountToken`, waits for authoritative PHP credit before finishing, recovers unfinished transactions from launch/foreground, and restores only the non-consumable. The coin-pack surface displays the authoritative wallet and refund debt; the dedicated Remove Ads surface omits irrelevant coin-balance presentation and shows only the ad-free purchase/restore path. A Debug-only local scheme uses an offline fake credit service; no physical Sandbox/TestFlight purchase has been accepted as validated yet.
- Profile/account deletion: Game Center connection appears above rank and personal-best information. The destructive account flow is isolated at the bottom of Profile, requires recent Google authentication plus the exact phrase `DELETE MY ACCOUNT`, validates the server's deleted/signed-out response before clearing local identity, and leaves the independent Game Center login untouched.
- Game Center: P-011 selects one permanent server-fed mirror of protocol-verified Arcade personal-best scores. The app now carries the Game Center entitlement, starts `GKLocalPlayer` authentication without blocking launch, presents Apple's sign-in controller when required, and shows connected/unavailable state plus retry in Profile. Game Center remains optional and cannot gate local play, PimPoPom/Google login, Hostinger ranking, achievements, shops, or purchases. Runtime identity-signature support is memory-only; no server binding exists yet, the iOS client never submits a score, and the Game Center board remains empty until Hostinger owns the verified mirror outbox.
- Device evidence: exact implementation commit `bab0709`, using the selected `com.otcsoftware.pimpopom` identity, was development-signed, passed strict signature verification, installed, and launched successfully through CoreDevice on the owner's wired iPhone SE (3rd generation) on iOS 26.3. CoreDevice reports its installed name as **PimPoPom**. This is an install-and-launch checkpoint, not a structured physical visual/touch/listening review. The earlier `d3ffd87` checkpoint used retired identity `com.otcsoft.pimpopom.alpha`; other historical installs remain recorded in `docs/DESIGN_QA.md`, and the 13 mini/13 Pro remain Simulator-only.
- Native StoreKit integration evidence: exact implementation commit `b9038fe` passed 29 core checks, 113 native unit tests, and all 23 XCUITest paths on the named iPhone SE 2022 Simulator with iOS 26.5. Xcode reported 136 passed tests with zero failures or skips, for 165 checks including the core package. The Debug local-StoreKit scheme and generic Release simulator build also pass. Coverage includes the exact five-product catalog/scheme, acknowledgement-before-finish, unfinished recovery, account switching, Family Sharing limits, exact PHP request/response validation, offline local credit, localized store entry points, and secure account deletion. No real App Store purchase or authenticated Hostinger write was sent.
- Earlier visual regression evidence: implementation commit `6743fc2` directly confirmed matching rounded Disco shell/cell curves with no rectangular ghost, outgoing active-cell light, transparent fading rating stamps, grouped score flyouts, Godlike absorption into the Speed Bar, the Zen rainbow/red HUD treatment, the 50-point banner host, and a retained 351-point board with a pet present. The earlier 13 mini/13 Pro regression remains recorded at commit `ec71d21` and was not rerun for this batch.
- App Store Connect record `PimPoPom` and explicit App ID `com.otcsoftware.pimpopom` exist under team `APX2925X66`; the first TestFlight upload/configuration is tracked under P-027. All five accepted StoreKit products are configured for the United States and Canada, with Family Sharing enabled only for the standalone Remove Ads non-consumable. They remain in pre-review state pending screenshots/metadata and Sandbox validation. Final logo/launch-cue acceptance and the ad account are not complete.
- No production App Store release has occurred. TestFlight availability is not an App Store submission or production-release claim.
