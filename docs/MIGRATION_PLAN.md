# PimPoPom native iOS migration plan

Status: Full production plan, based on migration source commit `675551adc715942ce2512c14d396d5d14e763f02` reviewed on 2026-07-14.

The current execution track began as the owner-only internal alpha in [`ALPHA_FAST_PATH.md`](ALPHA_FAST_PATH.md). It deliberately defers legal, ownership, accounting, a production-grade native identity/session contract, ads, and StoreKit work. Under P-014 the app reads and is prepared to write the existing Hostinger PHP service with shared production players and leaderboards. P-027 permits only the first direct-email TestFlight owner/QA cohort to exercise that same compatibility path; neither decision makes it the external-release architecture.

Do not begin paid purchases, live ads, backend deployment, public-link beta traffic, or traffic outside P-027's named cohort while deterministic parity, identity, and accounting remain unresolved.

## Deferred production Phase 0 — Owner and commercial setup

These steps require the Apple account holder or product owner. They are intentionally deferred during the local technical alpha and become prerequisites for external distribution and live services, not for a development-signed offline build.

### 0.1 Install and verify the development environment

1. Use a Mac supported by the current stable Xcode and macOS release.
2. Install the latest stable Xcode from the Mac App Store or Apple Developer downloads. Since 2026-04-28, App Store uploads must be built with **Xcode 26 or later using the iOS 26 SDK or later**; verify Apple's current submission requirement again when releasing.
3. In Xcode, install the iOS Simulator runtimes chosen for the support matrix and open Xcode once to complete components/licence setup.
4. Point command-line tools at that Xcode and verify the toolchain:

   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -license accept
   xcodebuild -version
   swift --version
   git --version
   ```

5. Prefer Swift Package Manager. Install Homebrew, formatters, linters, Fastlane, or other global tools only after the repository records and pins a real need; Xcode itself is the only required IDE/toolchain at bootstrap.
6. Have at least one compact 60 Hz iPhone and one ProMotion 120 Hz iPhone available for physical tests. Add an iPad only if iPad becomes a supported target.

### 0.2 Establish Apple ownership and commercial access

1. Confirm whether the seller is an individual or organization and enroll that entity in the Apple Developer Program with two-factor authentication.
2. Assign least-privilege App Store Connect roles for development, finance, marketing, support, and release. Keep the Account Holder recoverable.
3. Accept the Paid Apps Agreement and complete tax and banking information before testing paid IAP in the full sandbox workflow.
4. Declare App Store Connect Digital Services Act trader status. For EU distribution, complete verification of the contact details Apple will publish.
5. Create Sandbox Apple Accounts and an internal TestFlight group. Add physical test devices for development provisioning.
6. Choose a secure team secret store for App Store Connect API keys, In-App Purchase keys, signing material, Google configuration, ad configuration, and backend secrets. Never put these in Git or the app bundle.

### 0.3 Clear the product identity and create platform records

1. Perform name, domain, and trademark clearance for **PimPoPom** in intended storefronts before commissioning final branding.
2. Choose and register a reverse-DNS bundle identifier; do not use a placeholder in a submitted build.
3. Create the PimPoPom App Store Connect app record, SKU, primary language, Games category/subcategory, and intended territories.
4. Decide and record:

   - minimum iOS version;
   - iPhone-only versus universal iPhone/iPad;
   - portrait-only versus supported landscape orientations;
   - minimum supported device performance class;
   - whether Mac Designed for iPhone/iPad and visionOS compatibility remain enabled.

5. Add only accepted capabilities: Sign in with Apple, In-App Purchase, Game Center if in scope, and App Attest/DeviceCheck when its server path exists. Do not enable unused entitlements.
6. Choose semantic marketing-version policy and a monotonically increasing App Store build-number owner (CI is recommended).

### 0.4 Configure identity and backend environments

1. Create a **staging** backend with separate database, credentials, Apple/Google audiences, StoreKit environment handling, ad configuration, rate limits, and logs. Do not develop ranked or purchase flows directly against production.
2. Decide whether the current cross-platform profile/economy remains shared. The recommendation is one shared authoritative account and ledger through a new versioned native API.
3. Enable Sign in with Apple for the App ID and create the server key/configuration required to verify and revoke authorization.
4. If Google remains, create a Google OAuth client of type **iOS** for the bundle identifier and retain the backend server client ID. Configure explicit Apple↔Google account linking; never link on email alone.
5. Define native short-lived access/refresh sessions, Keychain storage, revocation, logout, recent-auth requirements, and account deletion.
6. Choose staging and production API base URLs. Create committed `.xcconfig` examples and ignored local values; never compile private server keys into the app.

### 0.5 Configure monetization accounts—but do not activate products yet

1. Choose StoreKit product identifiers and initial price/pack proposals:

   - one non-consumable **Remove Ads** product;
   - one or more consumable coin packs.

2. Decide paid-versus-earned coin accounting, spend order, refunds, debt, moderation reset behavior, guest-purchase policy, Family Sharing for Remove Ads, and cross-platform balance visibility before creating final SKUs.
3. Configure StoreKit products, localization, tax category, review screenshots, Sandbox testing, an In-App Purchase server key, and App Store Server Notifications V2 for staging and production.
4. Select the ad provider and consent platform. The current recommendation is Google Mobile Ads plus UMP behind app-owned adapters, but vendor adoption remains a decision.
5. Create separate test and production ad app/unit identifiers. Only test ads may run in Debug, CI, screenshots, and automated UI tests.
6. Decide contextual versus personalized advertising, ATT policy, child/teen treatment, age-screen policy, inappropriate-ad reporting, and regions where ads/IAP will be disabled.

### 0.6 Prepare legal, privacy, and support surfaces

1. Publish HTTPS Privacy Policy, Support, Terms, and account-deletion URLs owned by the seller.
2. Complete a data inventory covering identity digests, nickname, proof events, leaderboard results, coins, StoreKit transactions, ads/consent, device integrity signals, diagnostics, support, and retention.
3. Decide whether children are an intended audience or whether the Kids Category is in scope. This affects ad SDK configuration, consent, data collection, creative review, and storefront metadata.
4. Define public-nickname validation, reporting, blocking, moderation, appeal, and account-deletion handling.
5. Assign a private security contact and a public support contact.

### 0.7 Establish Git hosting and CI

1. Create a private remote repository named `PimPoPom`, add it as `origin`, and push this initial reviewed commit.
2. Protect `main`, require pull requests and checks, block force-pushes, enable secret scanning/dependency alerts, and define release/tag permissions.
3. Choose CI. Xcode Cloud is the recommended Apple-native starting point; GitHub Actions on managed macOS can supplement contract and documentation checks.
4. Give CI only environment-scoped credentials. Production release and App Store submission remain manual approvals.

### Phase 0 exit gate

- Every owner/account field in `docs/OPEN_QUESTIONS.md` is answered or explicitly deferred.
- Bundle, app, identity, StoreKit, ad, backend, and CI identifiers are recorded in a private configuration inventory.
- The support/device matrix and privacy/age strategy are accepted.
- No credential or private key exists in Git.

## Phase 1 — Freeze scope and extract parity evidence

1. Keep source baseline `675551adc715942ce2512c14d396d5d14e763f02` immutable for the first port.
2. Export deterministic JSON fixtures from the JavaScript engine for seeded target/decoy schedules, timing boundaries, score/rating rounding, streak overflow, mistakes, Arcade completion, Zen adaptation, and proof events.
3. Export server replay vectors for accepted, duplicate, invalid, cloned, review, and rate-limited proofs. Redact all production identity and proof data.
4. Inventory every screen and state: menu, Arcade, Zen, Results/Game Over, Profile/nickname, Leaderboard, Achievements, Pet Shop, Theme Shop, Settings, consent/paywall, offline/error states, and any deliberately excluded admin flow.
5. Inventory assets and licences. Do not copy Pancake until independent redistribution rights are proven or a replacement is accepted.
6. Freeze user-facing terminology to PimPoPom while preserving only necessary internal protocol identifiers.
7. Accept or revise P-003 through P-005 and the P-010 accounting recommendation.

Exit: parity fixtures and a signed-off MVP scope exist; no unresolved source-rights issue is hidden.

## Phase 2 — Scaffold the native workspace

1. Create the Xcode workspace and app target using the accepted bundle ID, deployment target, devices, and orientations.
2. Add modular targets/packages described in `docs/ARCHITECTURE.md`.
3. Enable Swift 6 language mode and strict concurrency checks appropriate to the accepted toolchain.
4. Create `Debug`, `Staging`, and `Release` `.xcconfig` files from committed examples, with visible staging branding and compile-time failures for placeholder release values.
5. Add `PrivacyInfo.xcprivacy`, an empty static launch screen, localized string catalogs, asset catalogs, test plans, and accessibility identifiers.
6. Add `Scripts/check.sh` for format, build, unit/parity/UI-static checks, package resolution verification, privacy validation where available, and `git diff --check`.
7. Configure CI to build every pull request and run deterministic tests without production credentials, live ads, or network dependence.

Exit: a clean checkout builds and tests in CI and on Simulator with no business logic or live service dependency.

## Phase 3 — Port the deterministic core

1. Port balancing constants and theme-independent color/glyph semantics into immutable Swift configuration.
2. Implement injected RNG and monotonic clock abstractions. Use a seeded RNG in fixtures and an accepted system random source at runtime; do not introduce a server seed without a new proof/ruleset decision.
3. Port Arcade and Zen as explicit state machines with synchronous commands and immutable snapshots.
4. Port scoring, rounded ratings, streak/multiplier overflow, mistake reset, decoys, dodges, board progression, recovery, and terminal results.
5. Port versioned proof-event emission without networking.
6. Run every Swift fixture against the frozen JavaScript/PHP expected output; use property tests for boundaries and randomized transition sequences.
7. Document any intentional mismatch as a proposed decision rather than weakening the fixture.

Exit: deterministic parity is exact for accepted fixtures, with no SwiftUI, SpriteKit, StoreKit, network, audio, or storage import in `PimPoPomCore`.

## Phase 4 — Build the native reaction surface

1. Embed a SpriteKit scene in the SwiftUI gameplay host with a fixed viewport.
2. Render 1×1, 2×2, and 4×4 states from core snapshots; keep target/decoy hit regions geometrically explicit.
3. Bridge presentation time and `UITouch.timestamp` onto one monotonic scale; resolve input/expiry races once.
4. Enable supported ProMotion cadence deliberately (`CADisableMinimumFrameDurationOnPhone = YES` and an accepted `SpriteView`/`SKView.preferredFramesPerSecond` policy); otherwise SpriteKit may stay at 60 fps. Test variable refresh and the user's **Limit Frame Rate** setting.
5. Implement the target response bar, reaction rating overlays, **Speed streak meter**, lives, score, elapsed time, pet-only gameplay placement, and reduced-motion variants.
6. Precompute/reuse nodes and textures; keep allocations, decoding, logging, analytics, ads, and network off the touch/render path.
7. Handle restart, Zen End run, background, interruption, rotation policy, memory warning, and scene teardown without stale commands.
8. Benchmark 60 Hz and 120 Hz physical devices, including variable cadence, thermal/low-power conditions, and external high-speed capture if precise latency claims are desired.

Exit: Arcade and Zen feel and score correctly on physical devices, and timing tests cover exact deadline, pre-presentation touch, queued expiry, multitouch, and background races.

## Phase 5 — Build app navigation, shops, and the requested layout

1. Implement SwiftUI navigation and state restoration for Main Menu, Arcade/Zen, Results, Leaderboard, Profile, Achievements, Theme Shop, Pet Shop, Settings, paywalls, and error states.
2. Implement the theme design system and accessible color-blind glyphs; render pets/habitats outside gameplay and only the selected visible pet beside the gameplay meter.
3. Add the fixed **ad container at the very bottom of gameplay, below the Speed streak meter (the requested “speed rating bar”) and above the bottom safe-area inset**. This is not the target response bar inside the color field. The vertical order ends with pet if visible, Speed streak meter, separator, reserved ad host, safe-area inset. Reserve its height before a run so fill/no-fill/removal cannot shift the board. The initial recommendation leaves it empty during active rapid play and fills ads only on non-active surfaces; compact-device suppression/collapse and confirmed Remove Ads may re-layout only between runs.
4. Add **Remove Ads** in the lower-right safe layout of the Main Menu with at least a 44×44-point accessible target, localized label, purchase state, and a path to Restore Purchases.
5. Add **Buy Coins** to both Theme Shop and Pet Shop. Both buttons present one shared coin-store sheet and show server-confirmed balance after purchase.
6. Ensure compact devices, Dynamic Type, VoiceOver, Switch Control, Reduce Motion, Increase Contrast, and safe-area layouts do not hide or overlap these controls.
7. Add screenshot/snapshot coverage for empty, loading, signed-out, owned, unaffordable, purchasing, failed, ad-filled, ad-free, and offline states.

Exit: the requested placements are present and stable using fake services; no control can grant coins, remove ads, or buy an item without its authoritative service.

## Phase 5B — Deliver backend prerequisites in the backend-owning repository

This is a named cross-repository workstream, not iOS client work. Use one reviewed backend issue, a separate worktree, and a focused branch such as `codex/pimpopom-native-api`; never develop it by dirtying or overwriting the current legacy `main` checkout.

1. Assign backend owner, repository, branch, staging target, migration owner, review owner, and rollback owner.
2. Freeze the `mobile-v1` OpenAPI/JSON Schemas, stable error codes, auth rules, idempotency semantics, compatibility window, and shared proof fixtures listed in `docs/API_CONTRACT.md`.
3. Add reviewed database migrations for provider identity links, native app sessions/revocation, account-deletion state, App Attest keys/challenges, StoreKit product mapping and immutable transaction status, server notifications, and the accepted earned/purchased ledger model.
4. Implement Apple and Google token verification/linking without changing the browser auth path. Encrypt any provider revocation material and keep private keys outside the repository/web root.
5. Implement native bootstrap/profile/leaderboard/run/achievement/pet/theme routes, native build/ruleset/proof acceptance, bearer authorization, rate limits, redacted audit logs, and exact idempotency.
6. Implement StoreKit JWS verification, `appAccountToken` binding, transaction reconciliation, refund/reversal handling, App Store Server Notifications V2, and a consent-aware response process for any Apple `CONSUMPTION_REQUEST`.
7. Add PHP/database/OpenAPI compatibility tests for web regressions, Swift/PHP proof vectors, duplicate/replayed transactions, migrations/idempotent reruns, old supported clients, account deletion, and moderation that preserves paid value.
8. Back up staging, apply migrations under the backend's lock, deploy the exact clean backend commit, record schema/API versions and rollback, and run end-to-end synthetic staging smoke tests.

Exit: the reviewed backend commit is deployed to staging, schemas are generated/consumed by PimPoPom tests, the browser client still passes, and rollback plus the supported-client window are recorded. This gate closes before native Phase 6 integration, StoreKit credit testing, or external TestFlight.

## Phase 6 — Add native identity and backend compatibility

1. Implement Sign in with Apple and Google Sign-In adapters, nonce/state validation, server token exchange, explicit provider linking, logout, reauthentication, and Keychain sessions.
2. Keep nickname entry/confirmation separate from provider display names and emails.
3. Add in-app account deletion with provider revocation and documented result/ledger retention or anonymization.
4. Implement typed, versioned profile, leaderboard, achievements, pets, themes, and settings endpoints against staging.
5. Implement ranked Arcade start, abandon, and finish using the native client platform/build plus shared ruleset/proof versions; never submit client totals as authoritative.
6. Add bounded retries only for safe/idempotent operations. A local or failed-start run is never uploaded later as ranked.
7. Add App Attest incrementally for sensitive challenges after the ordinary path is stable; define unsupported, reinstall, key-loss, and server-unavailable behavior.
8. Keep leaderboard administration web-only for the initial customer app unless the owner explicitly scopes a native admin surface.

Exit: cross-platform accounts, exact-result ranking context, cosmetics, achievements, run proof, revocation, and deletion pass staging tests without exposing raw provider identities.

## Phase 7 — Create PimPoPom branding, audio, and haptics

1. Explore and select a new PimPoPom logo/wordmark and app-icon family that remains recognizable at notification, Settings, Spotlight, and App Store sizes. Check name/logo clearance before final production.
2. Retain the editable source, generation prompts/references, creator/tool details, licence, color profiles, export settings, and hashes in `assets/branding/SOURCES.md`.
3. Generate or record an original short voice-like loading/activation sting with the exact contour **Pim (low) → Po (middle) → Pom (higher)**. Avoid imitation of any identifiable voice. Obtain a performer release if a person records it.
4. Retain a lossless master and deterministic/runtime export, measure loudness/peak/silence, hash every approved file, and record it in `assets/audio/SOURCES.md`.
5. Keep the system launch screen static. Play the sting only after the real app becomes active, never block first interaction, and respect Sound FX opt-out, Silent mode policy, interruption, route, and background behavior.
6. Port reviewed theme tone banks, loss cue, and menu/gameplay loops only after rights/provenance review. Use persistent `AVAudioEngine` voice pools with independent Sound FX/Music buses and no-late-cue behavior.
7. Add optional Core Haptics success/mistake patterns, feature detection, an independent setting, and graceful fallback.
8. Test speakers, headphones, Bluetooth route changes, phone calls, Siri, Control Center, background/foreground, volume changes, and repeated cold/warm launches on device.

Exit: brand assets and audio have documented rights/masters, and physical-device listening confirms latency, mix, interruptions, silent behavior, and no startup delay.

## Phase 8 — Implement StoreKit, paid coins, Remove Ads, and advertising

1. Accept a paid-value ledger design before coding coin packs. Recommended: separate earned and purchased balances/provenance, record each debit split, let earned debt absorb future earned credits, and never silently erase purchased value during moderation.
2. Implement StoreKit 2 product loading, localized pricing, purchase, pending/cancelled/error states, `Transaction.updates`, current-entitlement refresh, and StoreKit configuration tests.
3. For **Remove Ads**, verify the non-consumable transaction, observe revocation/refund, hide all ad requests/containers when entitled, and expose Restore Purchases using the supported StoreKit sync flow.
4. For coin packs, require a signed-in PimPoPom account, attach its internal UUID as `appAccountToken`, send the verified signed transaction to the server, credit its immutable transaction ID exactly once, refresh server balance, then finish the transaction.
5. Process App Store Server Notifications V2, refunds/reversals, duplicate delivery, account mismatch, reinstall, device change, and support reconciliation. If Apple sends a `CONSUMPTION_REQUEST` and consumption information is returned, obtain the separate required user consent (not ATT consent), answer through the current server endpoint within Apple's required window, and disclose that use in the privacy policy.
6. Integrate the chosen ad/consent SDK behind adapters. For AdMob, configure the required `GADApplicationIdentifier` and current `SKAdNetworkItems`. Before SDK initialization, set GMA `ageRestrictedTreatment`/TFAT and max content rating; its legacy TFCD/TFUA ad-request properties are deprecated. Separately set UMP `RequestParameters.isTaggedForUnderAgeOfConsent` before consent update when required because UMP still uses it and does not forward it to GMA. Gather/update consent before requesting ads, show Privacy Options when required, and request ATT only if the accepted configuration actually tracks across apps/sites.
7. Use anchored adaptive test banners in the reserved bottom host and add a clear separator. Never use live ads in development or automation.
8. Policy gate: continuously interactive gameplay is a discouraged banner placement for common ad networks. The recommended initial release keeps the requested bottom host reserved but loads a clickable ad only on non-active/menu/result states. Loading a live banner during Arcade or Zen requires explicit policy review plus proof that it cannot cause accidental taps or layout movement.
9. Provide an inappropriate-ad reporting route and no-fill/offline fallback. Purchases and gameplay cannot depend on consent to tracking or an ad fill.

Exit: StoreKit sandbox, server notification, refund, restore, duplicate, consent, test-ad, ad-free, account-switch, offline, and moderation scenarios pass on physical devices and staging.

## Phase 9 — Add native platform features selectively

1. **Implemented:** add non-blocking Game Center authentication after local play is already available without it; expose optional status/retry and keep every PimPoPom service independent.
2. **Selected/configured in App Store Connect:** use one permanent board, `com.otcsoftware.pimpopom.arcade.verified` / **Arcade**, as a high-to-low integer personal-best leaderboard.
3. **Backend work remaining:** bind Apple-signed runtime identity to an authenticated PimPoPom player, then submit only the current protocol-verified all-time best through an idempotent Hostinger outbox and Apple's server API. Retry mirror failures independently and coalesce older work so it cannot lower the board.
4. Do not add client score submission. Keep the board empty until the server binding/outbox, prerelease flag, and correction policy pass integration tests.
5. Add share sheets, deep links, notifications, widgets, or Live Activities only through separate product decisions; none are migration requirements.

Exit: Game Center failure or sign-out cannot block gameplay, server ranking, purchases, or account access.

## Phase 10 — Accessibility, localization, privacy, and resilience

1. Localize all player-facing text, App Store/IAP metadata, accessibility labels, errors, and privacy/consent surfaces for accepted launch languages.
2. Validate VoiceOver order, Dynamic Type, contrast, color-independent shapes, Reduce Motion, Switch Control, haptic/audio opt-outs, and minimum touch sizes.
3. Finalize the privacy manifest, SDK privacy reports, App Store privacy labels, age rating, ATT text if applicable, data retention, account deletion, and support workflows.
4. Test offline launch/local Zen, ranked-service outage, maintenance, timeouts, corrupt cache, Keychain loss, reinstall, low storage, memory pressure, Low Power Mode, thermal throttling, and clock/time-zone changes.
5. Run dependency/licence review, static analysis, log-redaction checks, API abuse tests, StoreKit replay tests, attestation recovery, and penetration review proportional to paid value.

Exit: no critical accessibility, privacy, security, localization, or resilience blocker remains.

## Phase 11 — Beta and App Store release

1. Archive a clean, reviewed commit with the release configuration and exact resolved dependencies.
2. Run internal TestFlight with staging first, then a narrowly controlled production-compatible build. Collect structured device/timing/audio/ad/IAP feedback without logging personal or replayable secrets.
3. Complete external beta, App Review demo/reviewer account, review notes for login/IAP/ads, screenshots, app previews, privacy/support URLs, export compliance, age rating, and IAP review assets.
4. Verify backend compatibility, rate limits, alerts, notification endpoints, account deletion, support playbooks, and a remote kill switch for ads/IAP presentation that cannot grant entitlements.
5. Submit only with explicit owner authorization. Prefer phased release, monitor crash/hang/energy/network/purchase and server health, and retain the previous compatible build/backend path.
6. Record commit SHA, version/build, Xcode/Swift version, archive checksum, TestFlight build, App Store version, API/ruleset/proof versions, StoreKit catalog version, ad SDK/consent versions, release time, and rollback/halt target.

Exit: App Store production is verified independently of TestFlight and documentation is updated to committed/released truth.

## Source-to-native migration matrix

| Legacy concern | PimPoPom destination | Verification |
| --- | --- | --- |
| Balancing/config | `PimPoPomCore` configuration | Golden JSON + boundary tests |
| Deterministic engine | `PimPoPomCore` state machine | Cross-runtime replay/property tests |
| Browser main/controller | SwiftUI app/run coordinators | Navigation and lifecycle UI tests |
| DOM reaction grid | SpriteKit scene/touch bridge | 60/120 Hz timing and race tests |
| Input timing helper | Presentation/touch monotonic adapter | Exact deadline/pre-presentation fixtures |
| Sound/music controllers | AVAudioEngine service | Buffer, overlap, interruption, device listening |
| Theme catalog/audio | Design system + audio manifests | Snapshot, contrast, hash/provenance checks |
| Pet catalog/controller | Pet feature + SpriteKit/SwiftUI renderer | State, direction, visibility, layout tests |
| Profile client | Typed native API client | Staging contract/idempotency tests |
| Cookie/CSRF auth | Native bearer/refresh session | Provider, Keychain, revoke/delete tests |
| Service worker/offline shell | Bundled app + explicit caches | Install/update/offline tests |
| PHP proof/economy authority | Existing backend with native API version | Shared fixture and staging replay tests |
| PWA install/release | Xcode archive, TestFlight, App Store | Signed-build provenance and smoke tests |

## MVP boundary

The first production candidate should include Arcade, Zen, core results, profile/nickname, cross-platform leaderboard, settings/accessibility, reviewed themes/pets/achievements, native audio, requested brand identity, stable ad host, Remove Ads, Buy Coins, StoreKit-safe accounting, consent/privacy, and account deletion. Native leaderboard administration, multiplayer, notifications, widgets, and new balance mechanics remain out of scope unless separately accepted.

## Official references to recheck during implementation

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple upcoming submission requirements](https://developer.apple.com/news/upcoming-requirements/)
- [SpriteKit](https://developer.apple.com/documentation/spritekit)
- [StoreKit 2](https://developer.apple.com/storekit/)
- [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- [App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [GameKit](https://developer.apple.com/documentation/gamekit)
- [Account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app)
- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios/start-integrating)
- [Google Mobile Ads banner guidance](https://developers.google.com/admob/ios/banner)
- [Google UMP for iOS](https://developers.google.com/admob/ios/privacy)
