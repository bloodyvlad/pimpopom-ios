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
- Hostinger Season 1 session, profile/nickname, public leaderboard, ranked ticket/abandon/finish client paths, signed-out local practice, and blocking retry/menu handling for unavailable session or required ranked-ticket preparation.
- Google Sign-In for iOS integration with ignored iOS OAuth configuration and the existing Web server audience.
- Five SE simulator UI smoke paths plus compact-layout checks on the iPhone 13 mini and iPhone 13 Pro simulator profiles.
- Original PimPoPom internal-alpha app-icon candidate with retained generation source, prompt, and hashes.
- Native Theme Shop and Pet Shop backed by the deployed catalog/economy endpoints, including server-authoritative balance, ownership, selection, pet visibility, and signed-out free-theme behavior.
- Shared disabled Buy Coins sheet in both shops; it contains no StoreKit product or value-granting path.
- Four code-native theme presentations and reviewed runtime art for Foka, Kesha, Tauta, Misha, server-derived Mitsuri/Muse, and the owner-approved native Pancake replacement with a glowing blue floor.
- Illuminated randomly tilted intro treatments, fading stamps for all four reaction ratings, authoritative tap-local score flyouts, non-shifting shop loading overlays, PHP-style Leaderboard/Profile/Game Over surfaces, and shared reaction-speed distribution components.
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
- A release-optimized Staging scheme, App Store Connect export profile, Game Center capability/entitlement, and non-blocking `GKLocalPlayer` service with Profile status/retry and ephemeral identity-signature support.
- Deterministic Game Center unit/UI coverage proving system authentication is suppressed in UI tests and that unavailable Game Center does not gate PimPoPom services.
- A five-product StoreKit 2 catalog, app-owned StoreKit actor/protocol, launch-time transaction listeners, acknowledgement-before-finish purchase controller, account-bound PHP credit bridge, and Debug-only offline StoreKit scheme.
- One shared localized Coin Store across the main menu, Theme Shop, and Pet Shop, with signed-in/binding gates, pending/cancelled/unverified/error states, authoritative wallet/refund-debt/ad-free presentation, unfinished-transaction retry, and standalone Remove Ads restore.
- Secure in-app account deletion requiring recent Google authentication and the exact confirmation phrase, with strict response validation before local session removal.

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
- Matched the PHP gameplay composition with a custom utility header, three-column HUD, near-full-width transparent SpriteKit board, and styled Speed Bar/multiplier above the bottom ad host.
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
- Darkened inactive Disco tiles to near-black `#0d0f12`, strengthened same-color active light, retained dark-silver scratch wear, and made the concrete/reflected-light surround visible behind the board and header.
- Made every Theme Shop preview depend only on its candidate theme, kept selected tiles undimmed, and made the gameplay Your Color swatch share the same geometry, border, glyph, and Pixel styling as a real board cell.
- Replaced the Preparing copy and tiny recovery feedback with centered backlit Get ready, Missed, and Too slow announcements; Get ready now delays a new run by exactly one second and is not replayed after a lost life.
- Changed companion turns to advance from the current sprite pose through adjacent directional frames, so a half-right pet reaches full-right in one frame instead of restarting at center.
- Resumed the Sound FX engine from the accepted tap before playing the bundled `oops` cue on life loss, while retaining the existing no-loss Zen and terminal-event rules.
- Unified all six live and preview glyphs behind one exact-size vector/pixel geometry, added crystal Light cells and clipped faint Pixel grain, and raised active Disco cells to the vivid saturated backlit palette while retaining the darker uneven inactive floor.
- Made coin/rank badge contents fully opaque above their button borders and kept their established lower-right/upper-right corner placement.
- Reused the Pet Shop horizontal-facing resolver in menu and gameplay, mapped inter-cell board gaps to protocol-valid Missed actions while retaining pet following and Zen's no-life-loss rule, lowered Pancake fifteen points only on menu/Leaderboard surfaces, and mirrored its clean full-right frame for artifact-free full-left presentation.
- Replaced the overlapping smooth cross paths with one solid outline, intensified Disco targets with highly saturated colors, and made Pixel's clipped block grain visibly brighter and square while keeping live cells, Theme Shop previews, and Your Color consistent.
- Updated native ranked compatibility to the deployed `20260718-1` PHP gate, require an exact saved-run UUID confirmation, retain retryable failed submissions, and show accepted/withheld status on Results.
- Reserved a right-aligned Leaderboard score column, removed the obsolete Legacy chip, omitted the current wallet balance from Achievements, and increased the Your Color outline to three points.
- Made the first three menu rules repeat once per cold launch, switching to the slogan rotation only after that launch's first completed Arcade or Zen game.
- Adopted `com.otcsoftware.pimpopom` as the app bundle identifier with matching test identifiers and a build-time metadata assertion.
- Changed the installed display name from **PimPoPom Alpha** to **PimPoPom** while retaining bundle identifier `com.otcsoftware.pimpopom`.
- Rebuilt Disco cell compositing around the shared web geometry: 22/15/11-point live radii, no square underlays, one rounded shell clip/stroke, retained scratch/glaze material, and a cached transparent-center additive halo above active cells and below feedback.
- Formatted reaction stamps as `Good - 802ms` with transparent backgrounds; Great/Good fade at their border lane, Godlike/Perfect shrink into the measured Speed Bar while its fill advances, and every accepted hit keeps its grouped score flyout 15 points above the tap until absorption completes.
- Replaced Zen's yin-yang emoji with a normal 40-point radial-rainbow Any cell, colored hearts and infinity red, renamed Speed streak to Speed Bar, lifted the pet/bar footer eight points, and reserved a standard 50-point disabled banner host without shrinking the near-full-width board.
- Confirmed that the existing synthesized Swift `Codable` models ignore the new `achievementSnapshot` response field and retained `/api/leaderboard` for its full rank/context shape.
- Accepted P-011's one-board server-fed mirror model: the iOS client never submits Game Center scores, while the future Hostinger path will bind Apple-signed identity and mirror only the authoritative protocol-verified Arcade all-time best.
- Replaced the internal-alpha Game Center placeholder with truthful optional authentication state while leaving local play, Google/PimPoPom login, Hostinger ranking, achievements, shops, and purchase placeholders independent.
- Corrected Foka's asymmetric right turn by mirroring its reviewed clean half-left/full-left cells into the semantic right poses; every other pet and the shared adjacent-pose animation plan remain unchanged.
- Increased the Your Color panel outline from three to five points with stronger outward glow, and replaced Zen's radial rainbow with the horizontal PimPoPom logo color progression.
- Changed score feedback to transparent `+N points` copy that flies and dissolves into the captured Points field, and locked Godlike/Perfect to a captured direct Speed Bar path so board refreshes cannot reverse either effect.
- Updated ranked compatibility to deployed build `20260719-1` and added backward-compatible session decoding for source-aware wallet, ad-free entitlement, and server-issued StoreKit binding state.
- Moved Game Center above rank/personal-best content in Profile and isolated Delete Account at the very bottom.
- Accepted the P-031 product/refund/account-deletion model and configured the five App Store Connect products for the United States and Canada, with Family Sharing only on standalone Remove Ads.
