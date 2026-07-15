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
- Two SE simulator UI smoke tests and compact-layout checks on the iPhone 13 mini and iPhone 13 Pro simulator profiles.

### Changed

- Internal alpha scope now reuses the existing deployed PHP backend and shared data under accepted decision P-014.
