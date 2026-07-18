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
- Exact web coin art, black-bordered coin/rank utility badges, signed-in Arcade position on the menu trophy, and a non-connecting Game Center profile placeholder.
- Ranked start/finish contract coverage proving that eligible native Arcade runs retain CSRF, ticket, build, ruleset, proof-version, and chronological event payloads.
- Live five-goal Achievements catalog and idempotent coin-claim flow backed by the existing Hostinger endpoints, with themed locked/ready/claimed cards, menu reward marker, authoritative balance refresh, stale-account protection, and deterministic API/UI coverage.
- Three selectable native app icons: ImageGen Glow as the primary plus Light glass and Pixel alternates, with iOS-owned persistence/confirmation, retained masters/prompts, and asset-catalog registration checks.
- A Home Screen `Change Icon` quick action backed by the `pimpopom://settings/icon` deep link, opening the icon selector directly from the app's context menu.

### Changed

- Replaced the disc-based internal app-icon candidate with a mask-safe stacked `Pim` / `Po` / `Pom` wordmark using the live logo gradients, a generated luminous backdrop, and a deterministic exact-text export path.
- Promoted the glow treatment to the default app icon and removed the black-outline candidate from the bundled icon choices while retaining its source for provenance.
- Internal alpha scope now reuses the existing deployed PHP backend and shared data under accepted decision P-014.
- Restored pet presentation toward the web parity reference at parent commit `7582b2d`: removed the in-flow menu pet icon, positioned the active pet independently, aligned shop pets with their habitats, and limited shop animation to a one-shot tap preview.
- Made selected, hidden, equipped, and server-derived special-pet state resolve consistently across the menu, shop, and active game. When a special companion overrides shop presentation, the shop now explains that the underlying selection still changes.
- Routed game-over and background abandonment directly to silent music state before subsequent menu routing, with stale asynchronous music transitions rejected.
- Replaced the animated generic progress indicator with an active-round-only response bar that resets immediately to full and drains toward empty.
- Rebuilt the main menu and Theme Shop around the reviewed web visual contract at parent commit `923a38e`: compact three-color wordmark/header, pet-safe hint stage, pink Arcade and green Zen actions, feature accents, themed panels/backgrounds, and two-column theme cards.
- Suppressed real audio output only for deterministic Debug UI-test launches, avoiding Simulator audio-service crashes without changing normal Simulator, device, or Release audio behavior.
- Replaced the scrollable floating main-menu dialog with a fixed safe-area layout and removed its build/backend/season diagnostics.
- Matched the PHP gameplay composition with a custom utility header, three-column HUD, near-full-width transparent SpriteKit board, and styled Speed streak/multiplier above the bottom ad host.
- Corrected Light theme surfaces without capsule cloud artifacts, increased Pixel typography by 25% throughout the app, and applied Pet Shop pink accents to internal actions.
- Added five-second menu pet sleep/wake, horizontal 15%-width half/full tap-follow facing, 40%-width gameplay placement, and surface-specific habitat alignment.
- Adopted the latest 26 web slogans with tap-to-advance and an intentional 10-second native rotation interval.
- Replaced the circular gameplay color swatch with a rounded square and removed the redundant visible “Tap [color]” prompt below the board while retaining its accessibility state.
- Shifted the menu pet left and slogans right, enlarged slogans, applied the requested surface-specific pet offsets, and repaired staged tap-facing animation coordinates in shops, menus, and gameplay.
- Added a Light-only readability plate behind the logo and replaced in-flow Theme/Pet Shop loading copy with a centered animated overlay that preserves layout.
- Removed the Leaderboard service footer and obsolete local-practice/version result panel while preserving automatic eligible Arcade submission and transient upload failure/retry feedback.
- Stacked Leaderboard pets under rank, widened player details, made each theme tile its own select/buy action, forced a black Disco preview base, and optically centered native color glyphs.
- Matched final companion placement and direction requests: Foka moves four points down in Pet Shop; Pancake moves twenty points down on every requested surface before the common ten-point gameplay lift; direction now depends only on the tap's horizontal distance from the pet.
- Moved the enlarged slogan back to a 10% right shift, enlarged and left-aligned the Pet Shop/Theme icons, and hid the pale duplicate hit-rating copy below the board while retaining feedback stamps and accessibility state.
- Darkened the inactive Disco tile by exactly 40% to `#908f8c`, brightened active tiles, added silver scratched-floor treatment, and retained the concrete/blurred-light surround using the reviewed in-repository textures.
- Made every Theme Shop preview depend only on its candidate theme, kept selected tiles undimmed, and made the gameplay Your Color swatch share the same geometry, border, glyph, and Pixel styling as a real board cell.
- Replaced the Preparing copy and tiny recovery feedback with centered backlit Get ready, Too early, and Too slow announcements; Get ready now delays a new run by exactly one second and is not replayed after a lost life.
- Changed companion turns to advance from the current sprite pose through adjacent directional frames, so a half-right pet reaches full-right in one frame instead of restarting at center.
- Resumed the Sound FX engine from the accepted tap before playing the bundled `oops` cue on life loss, while retaining the existing no-loss Zen and terminal-event rules.
- Unified all six live and preview glyphs behind one exact-size vector/pixel geometry, added crystal Light cells and clipped faint Pixel grain, and raised active Disco cells to the vivid saturated backlit palette while retaining the darker uneven inactive floor.
- Made coin/rank badge contents fully opaque above their button borders and kept their established lower-right/upper-right corner placement.
- Reused the Pet Shop horizontal-facing resolver in menu and gameplay, forwarded board-gap touches for presentation-only facing, lowered Pancake fifteen points only on menu/Leaderboard surfaces, and mirrored its clean full-right frame for artifact-free full-left presentation.
- Replaced the overlapping smooth cross paths with one solid outline, intensified Disco targets with highly saturated colors and opaque black rounded-corner surrounds, and made Pixel's clipped block grain visibly brighter and square while keeping live cells, Theme Shop previews, and Your Color consistent.
