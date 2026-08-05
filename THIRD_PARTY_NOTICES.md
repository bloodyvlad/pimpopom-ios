# Third-party notices

The native app resolves Google Sign-In, Google Mobile Ads, and Google User Messaging Platform through Swift Package Manager. Exact revisions are pinned in `PimPoPom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

| Package | Version | Source | Licence |
| --- | ---: | --- | --- |
| GoogleSignIn-iOS | 9.2.0 | `https://github.com/google/GoogleSignIn-iOS` | Apache-2.0 |
| AppAuth-iOS | 2.1.0 | `https://github.com/openid/AppAuth-iOS` | Apache-2.0 |
| GTMAppAuth | 5.0.0 | `https://github.com/google/GTMAppAuth` | Apache-2.0 |
| GTMSessionFetcher | 3.5.0 | `https://github.com/google/gtm-session-fetcher` | Apache-2.0 |
| GoogleUtilities | 8.1.2 | `https://github.com/google/GoogleUtilities` | Apache-2.0 |
| AppCheck | 11.3.1 | `https://github.com/google/app-check` | Apache-2.0 |
| Promises | 2.4.1 | `https://github.com/google/promises` | Apache-2.0 |
| Interop for Google SDKs | 101.0.0 | `https://github.com/google/interop-ios-for-google-sdks` | Apache-2.0 |
| Google Mobile Ads SwiftPM wrapper/binary distribution | 13.6.0 | `https://github.com/googleads/swift-package-manager-google-mobile-ads` | Apache-2.0 wrapper licence; Google Mobile Ads SDK terms also apply |
| Google User Messaging Platform SwiftPM wrapper/binary distribution | 3.1.0 | `https://github.com/googleads/swift-package-manager-google-user-messaging-platform` | Apache-2.0 wrapper licence; Google UMP/Ads terms also apply |
| Jersey 10 | Regular 400 | `https://github.com/google/fonts/tree/main/ofl/jersey10` | SIL Open Font License 1.1 |

Each resolved wrapper contains its Apache-2.0 `LICENSE`; Google's binary advertising
SDK terms also apply. The Jersey 10 licence is retained at
`assets/fonts/OFL-Jersey10.txt`. Before production distribution, re-audit the exact
resolved graph, signed XCFrameworks, privacy manifests, terms, and notices. Artwork
rights are tracked separately in `assets/**/SOURCES.md`; this notice does not clear
them.

The 2026-07-19 privacy-manifest review found that the pinned Google Mobile Ads binary declares required-reason access for system boot time, UserDefaults, and disk space; linked coarse location, advertising data, product interaction, and Device ID (Device ID marked for tracking); and unlinked crash, performance, and diagnostic data. The pinned UMP binary declares UserDefaults access plus unlinked coarse location, performance, and product interaction for app functionality. These are vendor declarations, not a claim that every category is exercised in PimPoPom's current contextual configuration. Re-run Xcode's aggregate archive privacy report and reconcile App Store privacy answers whenever either SDK pin or runtime ad configuration changes.
