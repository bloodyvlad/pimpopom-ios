# Changelog

All notable PimPoPom changes will be recorded here. The project uses semantic marketing versions and monotonically increasing App Store build numbers once an Xcode target exists.

## Unreleased

### Added

- Separate native iOS repository under the PimPoPom product name.
- Initial migration, architecture, gameplay, API, monetization/privacy, testing, release, and asset-provenance documentation.
- Reproducible Swift 6/Xcode project, local-only Bootstrap Alpha UI, disabled ad/purchase adapters, and privacy manifest.
- Pure `PimPoPomCore` package with the frozen reaction-rating and score rules plus deterministic tests.
- Technical local-device fast path and SE 2022, iPhone 13 mini, and iPhone 13 Pro simulator setup.
- Full deterministic Arcade/Zen state machine, proof-v1 event stream, input-timing helpers, and 29 Swift tests.
- SpriteKit reaction board with one monotonic presentation/touch clock, SwiftUI gameplay/results, lifecycle abandonment, and deterministic UI-test launch mode.
- Hostinger Season 1 session, profile/nickname, public leaderboard, ranked ticket/abandon/finish client paths, plus local-practice fallback.
- Google Sign-In for iOS integration with ignored iOS OAuth configuration and the existing Web server audience.
- Five SE simulator UI smoke paths plus compact-layout checks on the iPhone 13 mini and iPhone 13 Pro simulator profiles.
- Original PimPoPom internal-alpha app-icon candidate with retained generation source, prompt, and hashes.
- Native Theme Shop and Pet Shop backed by the deployed catalog/economy endpoints, including server-authoritative balance, ownership, selection, pet visibility, and signed-out free-theme behavior.
- Shared disabled Buy Coins sheet in both shops; it contains no StoreKit product or value-granting path.
- Four code-native theme presentations and reviewed runtime art for Foka, Kesha, Tauta, Misha, server-derived Mitsuri/Muse, and the owner-approved native Pancake replacement with a glowing blue floor.
- Illuminated randomly tilted intro and Perfect/Godlike millisecond stamps, non-shifting shop loading overlays, PHP-style Leaderboard/Profile/Game Over surfaces, and shared reaction-speed distribution components.
- Independent persistent Music and Sound FX controls using one native audio engine, four migrated theme suites, the shared loss cue, menu/gameplay/silent routing, and lifecycle/interruption handling.
- Original deterministic rising Pim–Po–Pom activation-cue candidate, with 24-bit master, generator, measurements, and hashes.
- Native cosmetics/preferences/API-contract tests, including coalesced session loading, CSRF credential wiring, and stale-account response rejection; shop/settings UI tests; and deterministic validation of every migrated runtime/master/source asset.
- Current reviewed Muse special-pet sprite/floor assets and deterministic coverage for pet presentation geometry, selected/visible mutations, gameplay lifecycle audio routing, and response-progress semantics.
- Simulator regression coverage for static-until-tapped Pet Shop previews, special-pet presentation in menu/gameplay, and a decreasing Arcade response bar.
- Deterministic UI-test fixtures for all four themes, compact-menu geometry coverage, and two-column Theme Shop layout coverage.
- Reviewed Jersey 10 Pixel font and exact Disco concrete/tile textures with retained sources, licence/provenance, hashes, and resource validation.
- Persisted Glyphs setting wired through theme previews, the gameplay color header, feedback, and SpriteKit cells.
- StoreKit-safe Remove Ads placeholder, 26-item main-menu motivation pool, pet-facing resolver, and deterministic pet sleep/wake coverage.

### Changed

- Internal alpha scope now reuses the existing deployed PHP backend and shared data under accepted decision P-014.
- Restored pet presentation toward the web parity reference at parent commit `7582b2d`: removed the in-flow menu pet icon, positioned the active pet independently, aligned shop pets with their habitats, and limited shop animation to a one-shot tap preview.
- Made selected, hidden, equipped, and server-derived special-pet state resolve consistently across the menu, shop, and active game. When a special companion overrides shop presentation, the shop now explains that the underlying selection still changes.
- Routed game-over and background abandonment directly to silent music state before subsequent menu routing, with stale asynchronous music transitions rejected.
- Replaced the animated generic progress indicator with an active-round-only response bar that resets immediately to full and drains toward empty.
- Rebuilt the main menu and Theme Shop around the reviewed web visual contract at parent commit `923a38e`: compact three-color wordmark/header, pet-safe hint stage, pink Arcade and green Zen actions, feature accents, themed panels/backgrounds, and two-column theme cards.
- Suppressed real audio output only for deterministic Debug UI-test launches, avoiding Simulator audio-service crashes without changing normal Simulator, device, or Release audio behavior.
- Replaced the scrollable floating main-menu dialog with a fixed safe-area layout and removed its build/backend/season diagnostics.
- Matched the PHP gameplay composition with a custom utility header, three-column HUD, near-full-width transparent SpriteKit board, and styled Speed streak/multiplier above the bottom ad host.
- Corrected Light theme surfaces without capsule cloud artifacts, increased Pixel typography by 10%, extended Pixel type to Leaderboard/Pet Shop/Settings, and applied Pet Shop pink accents to internal actions.
- Added five-second menu pet sleep/wake, original 30-degree tap-follow facing, 40%-width gameplay placement, and five-point Foka/Misha habitat alignment.
- Adopted the latest 26 web slogans with tap-to-advance and an intentional 10-second native rotation interval.
- Replaced the circular gameplay color swatch with a rounded square and removed the redundant visible “Tap [color]” prompt below the board while retaining its accessibility state.
- Shifted the menu pet left and slogans right, enlarged slogans, applied the requested surface-specific pet offsets, and repaired staged tap-facing animation coordinates in shops, menus, and gameplay.
- Added a Light-only readability plate behind the logo and replaced in-flow Theme/Pet Shop loading copy with a centered animated overlay that preserves layout.
