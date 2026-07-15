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
- Four code-native theme presentations and reviewed runtime art for Foka, Kesha, Tauta, Misha, and server-derived Mitsuri; Pancake uses labelled code-native placeholder art.
- Independent persistent Music and Sound FX controls using one native audio engine, four migrated theme suites, the shared loss cue, menu/gameplay/silent routing, and lifecycle/interruption handling.
- Original deterministic rising Pim–Po–Pom activation-cue candidate, with 24-bit master, generator, measurements, and hashes.
- Native cosmetics/preferences/API-contract tests, including coalesced session loading, CSRF credential wiring, and stale-account response rejection; shop/settings UI tests; and deterministic validation of every migrated runtime/master/source asset.

### Changed

- Internal alpha scope now reuses the existing deployed PHP backend and shared data under accepted decision P-014.
