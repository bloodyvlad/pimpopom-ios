# TestFlight and App Store release

Production submission requires explicit owner authorization. A clean TestFlight build is not proof that an App Store version is live.

## Version identity

Record for every candidate:

- PimPoPom Git commit SHA and tag;
- marketing version and monotonically increasing build number;
- Xcode, Swift, iOS SDK, macOS runner, and resolved package versions;
- bundle ID, signing team, configuration, entitlements, and environment;
- API, ruleset, proof, economy catalog, StoreKit product catalog, ad SDK, and consent SDK versions;
- archive/export checksum and App Store Connect build identifier.

Use semantic marketing versions once public. CI should own build-number allocation to prevent collisions.

## Pre-archive gate

1. Confirm `git status --short` is clean and the intended commit is reviewed on protected `main` or a release branch/tag.
2. Run `Scripts/check.sh`, `git diff --check`, dependency/licence/security review, and the full release test plan.
3. Confirm Release points only to production API and uses production bundle/capabilities while retaining test-safe diagnostics; no placeholder, staging URL, test IAP catalog, debug menu, or test/live ad mismatch.
4. Validate `PrivacyInfo.xcprivacy`, aggregated SDK privacy report, App Store privacy labels, export compliance, age rating, ATT purpose if used, and required usage descriptions.
5. Confirm public Privacy, Terms, Support, account deletion, and ad-report URLs work over HTTPS.
6. Confirm Paid Apps Agreement, tax/banking, DSA trader status and EU published-contact verification where distributed, IAP availability/localization/review media, server notification endpoints, Sign in with Apple, Google OAuth audience, App Attest environment, and Game Center configuration.
7. Verify backend deployment supports this API/ruleset/proof/build before archive distribution and remains compatible with the prior live app. A P-054 candidate may be uploaded for isolated iOS review while the documented backend task is pending, but it must be described as compatibility-limited and cannot be promoted as end-to-end Game Center-ready until current-profile-wins reassignment is deployed and smoke-tested.
8. Run the physical-device release matrix and document gaps explicitly.

### Advertising configuration gate

| Candidate | Required ad configuration |
| --- | --- |
| Debug/local automation | Real PimPoPom AdMob App ID, Google demo banner/interstitial units, no custom test-device ID |
| Named Staging/TestFlight QA | Committed demo defaults; committed owner IDFV fingerprints select the committed production units plus registered GMA test-device ID only on those installations, with one exact no-fill fallback to official demo inventory |
| Owner Ads QA | Committed production units plus the owner's registered GMA test-device ID; every creative must visibly say **Test mode** |
| Public Release | Ignored production units, `live` mode, no test-device identifier; only after separate owner authorization |

Before any ad-enabled archive, run the configuration validator and inspect the built `Info.plist`. Before public live activation, also verify the current aggregate archive privacy report and App Store privacy answers, UMP consent/privacy-options messages, accepted age treatment, `https://otcsoft.com/app-ads.txt` using the exact personalized AdMob line, AdMob app linkage/readiness, banner/interstitial physical evidence, and server-authoritative Remove Ads behavior. Do not infer or construct the `app-ads.txt` publisher line from memory. The closed-beta owner fingerprints and GMA test-device ID are intentionally committed, but neither belongs in App Store metadata or a public live Release archive.

### Multiplayer configuration gate

Before archiving a Multiplayer candidate:

1. Confirm the backend compatibility value is build `20260729-1`, ruleset `multiplayer-own-color-v1`, protocol/proof version 1, and that the private cookie/CSRF lobby routes plus public Multiplayer leaderboard pass staging/live smoke probes without modifying unrelated production data.
2. Confirm the binary carries Game Center entitlement, uses persistent scoped player IDs, bridges only PHP's private positive 31-bit `playerGroup` into `GKMatchRequest`, and contains no direct `GKLeaderboard.submitScore` or `GKAchievement.report` call.
3. Run the complete automated Multiplayer acceptance plan in [`TESTING.md`](TESTING.md), including tuple/replay parity, 250 ms coordinator watermark, packet gaps/snapshots, fixed-coordinator cancellation, UI/accessibility, and zero economy/achievement side effects.
4. Record real 2-, 3-, and 4-player physical/TestFlight evidence before describing the feature as multi-device validated. A Simulator cannot close the GameKit transport gate.
5. Confirm the Game Center score leaderboard exact vendor identifier is `com.otcsoftware.pimpopom.multiplayer.verified`, its localization is ready, and the PHP publisher has the matching allowlisted prerelease lane. Do not make iOS publish a score as a fallback.
6. Use trust copy **protocol-verified, peer-consistent**. Do not claim server-authoritative gameplay, human verification, bot protection, or collusion resistance.

## Archive and upload

1. Archive from the exact clean commit with Release configuration and automatic/manual signing according to team policy.
2. Validate the archive, entitlements, embedded provisioning, symbols, privacy report, asset catalog, launch screen, app icon, bitcode setting if applicable to current toolchain, and absence of secrets/private keys.
3. Export/store dSYMs and symbol artifacts under controlled retention.
4. Upload through Xcode/Xcode Cloud/App Store Connect and record the processed build ID.
5. Do not reuse a build number or claim upload success until App Store Connect finishes processing.

## TestFlight progression

### First named cohort (P-027)

- Archive the clean `PimPoPom Staging` scheme. This configuration is release-optimized but still uses the existing Hostinger compatibility service and shared Season 1 data; it is not a separate data environment.
- Do not export as **TestFlight Internal Only** because the same processed build serves the named internal and external groups.
- Confirm the exported App Store payload is distribution-signed, has `com.apple.developer.game-center = true`, has no `get-task-allow`, contains no private key, and reports version/build `1.01 (4)` before upload.
- Use direct email groups only: one internal owner group and one external QA group. Do not enable a public link. An internal tester must already be an App Store Connect user with app access; external tester access is limited to TestFlight.
- For StoreKit/ad-enabled Staging builds, disclose that the app uses the live compatibility service and real shared player/ranking/purchase data, Google demo-labelled ads behind UMP consent, five Sandbox products, server acknowledgement before credit, and in-app deletion. From build `1.02 (9)`, also disclose that PHP asynchronously mirrors only protocol-verified Arcade personal bests and authoritative achievement unlocks; the client does not submit either directly. For P-054 candidates, explain that iOS may present Apple's standard Game Center authentication at launch and silently associates the active Game Center player after primary PimPoPom sign-in. A Multiplayer candidate must additionally disclose the 2–4-device/account requirement, no coins/achievements, peer-to-peer `GKMatch` transport, PHP transcript settlement, and protocol-verified peer-consistent trust limit. Do not describe queued work as already visible in Apple.
- Submission to TestFlight Beta App Review is not approval. Record processing, review, and invitation states independently.

### Internal

- Smoke cold install/update/reinstall, every enabled mode, identity/linking, ranked proofs, leaderboards, automatic nonblocking Game Center launch authentication, later silent primary-profile reconciliation, repeated **See stats**, achievements, themes/pets, audio/haptics, consent/test or approved diagnostic ads, Remove Ads, coin purchase, restore, account deletion, and support URLs. Confirm Arcade Your Color remains empty through preparation/Get Ready and reveals only the actual run color. For Multiplayer candidates, exercise at least one real 2-player match before internal distribution and retain the same exact transcript/submission/settlement evidence from both devices.
- Verify production-like server rate limits/alerts without using live ad clicks or uncontrolled real purchases.

### External

- Provide beta description, feedback contact, privacy links, required export information, and App Review access.
- Expand device/OS/locale/region coverage and monitor crashes, hangs, energy, purchase failures, API compatibility, proof review rate, and support incidents.
- Never expose production admin capabilities to general testers.

## App Store submission

Prepare:

- localized name **PimPoPom**, subtitle, description, keywords, category, age rating, support/marketing/privacy URLs;
- real in-app screenshots and previews, including disclosure of paid content where relevant;
- review notes explaining Apple/Google login, nickname confirmation, local play, Arcade and Multiplayer ranked flows, Multiplayer's 2–4-device Game Center requirement, ads/consent, Remove Ads, Buy Coins, restore, and account deletion;
- a stable reviewer account or approved demo path, a live review backend, and exact navigation to every IAP;
- IAP review screenshots/metadata and any Game Center assets;
- contact information for review and urgent server issues.

Submit only when every configured IAP is functional and visible or clearly explained. Prefer phased release after approval unless an urgent synchronized backend launch requires another accepted plan.

## Production verification

After release:

1. Confirm the exact App Store version/build and seller page.
2. Fresh-install from the store and test launch, consent, sign-in providers, nickname, local Zen, ranked Arcade, any enabled Multiplayer lobby/match/settlement, finish/rank, shops, a controlled purchase/restore path, Remove Ads, audio/haptics, backgrounding, account deletion entry, and support links.
3. Verify App Store server notifications, ledger idempotency, error/redaction logs, crash symbols, rate-limit health, ad configuration, and no staging traffic.
4. Record release time, storefront rollout, backend version, smoke-test account/result cleanup, and any issue/mitigation.

## Halt and rollback

iOS binaries cannot be instantly rolled back on every installed device. Prepare to:

- halt a phased release;
- remove the app from affected storefronts and disable affected IAP products where appropriate; this does not restore the previous binary;
- remotely disable ad/IAP presentation or ranked starts through a server-owned, fail-safe capability gate that cannot grant value;
- keep the prior app's API/ruleset working;
- ship an expedited corrective build;
- restore backend state from audited migrations/backups without deleting immutable purchase evidence;
- notify support/review/users proportionally and reconcile failed purchases idempotently.

Never break the previous live client merely to simplify a new release.

## TestFlight release records

### Pending PimPoPom 1.2 (16) Multiplayer candidate — not uploaded

- **Git source:** exact integrated release commit and branch are **pending**. This section must be updated from the clean commit actually archived; documentation commits or intermediate feature commits are not release identity.
- **Toolchain/identity:** expected bundle `com.otcsoftware.pimpopom`, Game Center entitlement, marketing version `1.2`, next build `16`; exact Xcode/Swift/SDK, signing, archive checksum, dSYM, and App Store Connect build ID are **pending**.
- **Backend dependency:** Hostinger backend release `20260729-1`; `/api/mobile/v1/multiplayer`; `multiplayer-own-color-v1`; protocol/proof version 1; 2–4 own-color players; no coins or achievements.
- **Verification:** deterministic core/service/UI checks, named iPhone 17 Simulator evidence, and exact result bundles/counts are **pending**. Real 2-, 3-, and 4-player physical/TestFlight GameKit evidence is also **pending** and must remain an explicit limitation after upload if not completed.
- **Beta metadata:** update Beta App Description and What to Test for create/join/readiness, complete GameKit roster, 2–4-player synchronized targets/decoys/points/multipliers/pets/crown/tones, bounded reconnect/snapshot, collecting/settled/review results, exact-submission retry, Multiplayer leaderboard, and confirmation that the mode grants no coins/achievements. Review notes must state that primary sign-in, confirmed nickname, Game Center, and multiple devices/accounts are required for this mode while Arcade/Zen remain independently evaluable.
- **Game Center leaderboard:** app Apple ID `6792328590`; vendor ID `com.otcsoftware.pimpopom.multiplayer.verified`; leaderboard resource `2b03eb62-0107-431d-b4dc-347317e10dc2`; leaderboard version `c582d3da-76c9-44a2-86f8-4b135f73185a`; localization `d000beaa-8a4d-4435-9186-e117ab4cfefb`.
- **App-review association:** add-only association exists on draft review submission `8069f585-f7a1-4a4e-833a-0b90ce3d0f8f`; review item `ODA2OWY1ODUtZjdhMS00YTRlLTgzM2EtMGI5MGNlM2QwZjhmfDEyfGM1ODJkM2RhLTc2YzktNDRhMi04NmY4LTRiMTM1ZjczMTg1YQ`; component and item reported `READY_FOR_REVIEW`. The draft has not been submitted (`submittedDate` is null); this is not App Store approval, production release, or TestFlight evidence.
- **Trust/limitations:** PHP replays matching transcripts and may publish each verified personal best; iOS never publishes directly. Clean rows are **protocol-verified, peer-consistent**, not server-authoritative, human-verified, bot-proof, or collusion-proof. Protocol v1 has fixed coordinator/no host migration and bounded snapshot recovery; failed exact recovery cancels/forfeits.

### PimPoPom 1.2 (15) — 2026-07-29

- **Git source:** `a87a4ecf33fd541b05f799a1a5523673d96c1cf0` on `codex/decoy-persistence-build15`; the exact archived release commit is also on `origin/main`.
- **Toolchain:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2.
- **Identity:** bundle `com.otcsoftware.pimpopom`; Apple Distribution team `APX2925X66`; Apple Sign In and Game Center entitlements; marketing version/build `1.2 (15)`.
- **Verification:** `Scripts/check.sh` passed project regeneration, strict formatting, asset/source/licence hashes, ad-configuration guards, Info/privacy lint, 36 deterministic core checks, a generic-iOS Simulator build, and all 228 native unit/UI tests on the named iPhone 17 Simulator with iOS 26.5. Xcode reported zero failures or skips: 264 checks including the core package. The focused gameplay/API subset also passed 54/54 before the full run. Full result bundle: `/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hgpdhdhlwjuyrybrnevtvnzivund/Logs/Test/Test-PimPoPom-2026.07.29_14-32-11-+0200.xcresult`.
- **Archive and symbols:** uploaded from `/Users/vlad/Documents/PimPoPom-release-artifacts/1.2-15/PimPoPom-1.2-15-a87a4ec.xcarchive`; deterministic sorted-file manifest SHA-256 `5118de71341b051e100757866aab1254155ccbb8f7ecc27127e8626c6bc9b1fe`. Xcode's remote App Store export re-signed the package with Apple Distribution. The local archive was removed after Apple accepted the build. Retained dSYM: `/Users/vlad/Documents/PimPoPom-symbols/1.2-15/PimPoPom-1.2-15-a87a4ec-95C223A5-6853-38E9-BD5A-9D59B796919D.dSYM.zip`, SHA-256 `c588e64b9c3187835e6e5ce2b890f1318894e21e386d305a91eacde448e4e1ee`.
- **App Store Connect:** build `41cea27a-b807-42cc-914a-1c266fe941af` processed `VALID`; icon present; `usesNonExemptEncryption = false`; Beta App Review `APPROVED`; Internal QA and External QA both `IN_BETA_TESTING` with automatic notification enabled. The English build localization asks testers to verify rapid recovery taps, persistent independent decoys and dodges, color changes, the 70-second overlap transition, and long-run pacing.
- **Runtime contract:** every board tap is ignored during post-miss recovery; decoys persist independently for 1–3 seconds through correct hits and subsequent targets, reserve their cells, award dodges only on natural expiry, and overlap only after 70 seconds. Visible decoy colors are excluded from the next Arcade player-color change, with current-color fallback. Late 4×4 pressure now contracts 5 ms per hit.
- **Backend dependency:** ranked Arcade requires build `20260729-1`, ruleset `reaction-proof-v3`, proof version 2, and the documented color-bearing tuples. At archive/upload time the separately owned PHP validator was pending, so the client retained its retryable gate. Hostinger backend release `20260729-1` subsequently deployed the matching replay while retaining supported prior-client compatibility. This iOS release did not modify or deploy PHP/Hostinger.
- **Prior compatible build:** TestFlight 1.2 (14).

### PimPoPom 1.2 (14) — 2026-07-28

- **Git source:** `a84fe262f18777a4ac693bef1132ff0076f2db2c` on `codex/unique-player-names-build14`; the exact archived release commit is also on `origin/main`.
- **Toolchain:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2.
- **Identity:** bundle `com.otcsoftware.pimpopom`; Apple Distribution team `APX2925X66`; Apple Sign In and Game Center entitlements; marketing version/build `1.2 (14)`.
- **Verification:** project regeneration, strict formatting, asset/source/licence hashes, ad-configuration guards, Info/privacy lint, 29 deterministic core checks, `git diff --check`, a generic-iOS app build, and a compile-only generic-iOS test bundle passed. Per the owner's explicit instruction, no Simulator or physical-device test ran for this candidate; it is neither Simulator-tested nor device-tested.
- **Archive and symbols:** uploaded from `/Users/vlad/Documents/PimPoPom-release-artifacts/1.2-14/PimPoPom-1.2-14-a84fe26.xcarchive`; deterministic sorted-file manifest SHA-256 `b97545739573494971aeb0881f5ee92c4aa49f1af0516b4226b038db109d4e86`. The local archive was removed after Apple accepted the build. Retained dSYM: `/Users/vlad/Documents/PimPoPom-symbols/1.2-14/PimPoPom-1.2-14-a84fe26-0D44DBB0-BA9E-351E-95D1-83748C9FBBA1.dSYM.zip`, SHA-256 `1407667f147fb87070db5730ad3d1c5fb618ec3252f4b135d1885c9725940b41`.
- **App Store Connect:** build `0c92c8da-ff91-4c99-9a05-cf7f00984fdd` processed `VALID`; icon present; `usesNonExemptEncryption = false`; Beta App Review `APPROVED`; Internal QA and External QA both `IN_BETA_TESTING` with automatic notification enabled. The English build localization asks testers to verify whitespace rejection, debounced availability, unchanged-current-name handling, unavailable fallback, and authoritative save-time conflicts.
- **Runtime contract:** Profile performs a cancellable 400 ms authenticated availability check, rejects Unicode whitespace locally, disables Save while checking/taken, keeps authoritative Save available after validation transport failure, and maps save-time `409` to the exact same red taken notice. Availability is advisory and never reserves a name.
- **Backend dependency:** the matching PHP endpoint, owner exclusion, normalization, and confirmed-name unique constraint remain a separately owned parent-repository deployment. This iOS release did not deploy or modify Hostinger and must not be described as end-to-end unique until that release is live.
- **Prior compatible build:** TestFlight 1.2 (13).

### PimPoPom 1.2 (13) — 2026-07-28

- **Git source:** `22a5dd115e22288ff5f4e2ff717280f2c6e2d952` on `codex/game-center-auto-link-build13`; the exact archived release commit is also on `origin/main`.
- **Toolchain:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2.
- **Identity:** bundle `com.otcsoftware.pimpopom`; Apple Distribution team `APX2925X66`; Apple Sign In and Game Center entitlements; marketing version/build `1.2 (13)`.
- **Verification:** 29 deterministic core checks passed. The full native/unit/UI run passed 220 tests; its sole interrupted exact-phrase account-deletion case passed on immediate isolated rerun after the one-time iOS bilingual-keyboard onboarding overlay was consumed. Project regeneration, strict formatting, focused Game Center/Profile/Arcade UI paths, asset/source/licence, Info/privacy/ad-configuration, generic Swift 6 Simulator build, and `git diff --check` gates passed.
- **Archive and symbols:** uploaded from `/Users/vlad/Documents/PimPoPom-release-artifacts/1.2-13/PimPoPom-1.2-13-22a5dd1.xcarchive`; deterministic sorted-file manifest SHA-256 `ec5f8e86ceb29fcde0e6bc03467b0a7ac30a8503f4bc35e9bade500faf3d4029`. The local archive was removed after Apple accepted the build. Retained dSYM: `/Users/vlad/Documents/PimPoPom-symbols/1.2-13/PimPoPom-1.2-13-22a5dd1-E13BDC2D-C718-3063-82BB-484438A6ABB1.dSYM.zip`, SHA-256 `fc1ed20b08991fa5d2d2ed499500267e24e0c9e32925ba2a7bf2cf90e418b366`.
- **App Store Connect:** build `976da494-5c39-48bf-85a7-1521617aa2ac` processed `VALID`; icon present; `usesNonExemptEncryption = false`; Beta App Review `APPROVED`; Internal QA and External QA both `IN_BETA_TESTING` with automatic notification enabled.
- **Runtime contracts:** authenticates Game Center automatically through Apple's nonblocking system flow, silently reconciles the current persistent GameKit identity after primary PimPoPom login, retries on relevant foreground/session/player changes, exposes only repeatable **See stats**, and keeps Arcade **Your Color** empty until the actual run starts. PHP remains the only score/achievement publisher; the client never calls GameKit score or achievement submission APIs.
- **Known limitation:** the current-profile-wins reassignment transaction is intentionally not part of this iOS archive. Until the separate parent-PHP task is deployed and smoke-tested, an identity already bound to another internal profile may still be rejected by the live backend; iOS defers that supplementary side effect without blocking gameplay.
- **Prior compatible build:** TestFlight 1.2 (12).

### PimPoPom 1.2 (12) — 2026-07-27

- **Git source:** `a87a1ea60ba364902e8d2da982b29c82bb6d55b9` on `codex/game-center-release-12`; the exact release commit is also on `origin/main`.
- **Toolchain:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2.
- **Identity:** bundle `com.otcsoftware.pimpopom`; Apple Distribution team `APX2925X66`; Apple Sign In and Game Center entitlements; marketing version/build `1.2 (12)`.
- **Verification:** `Scripts/check.sh` passed 29 deterministic core plus 220 native/unit/UI tests on the named iPhone 17 Simulator, 249 total with zero failures or skips. Project regeneration, strict formatting, asset/source/licence, Info/privacy/ad-configuration, generic Swift 6 Simulator build, and `git diff --check` gates passed.
- **App Store Connect:** build `c454da74-ee58-48e9-ac49-2f3af2eb0b93` processed `VALID`; Beta App Review `APPROVED`; Internal QA and External QA both `IN_BETA_TESTING`.
- **Runtime contracts:** removes the user-visible Verify Player gate after durable linking, retains repeatable delegate-managed Game Center dashboard access and explicit Disable behavior, uses Apple's one-authorization Apple login-or-create path, hides redundant primary-provider Link actions, and fixes Privacy Choices spacing. PHP remains the only Game Center score/achievement publisher.
- **Known limitation:** automatic launch authentication/current-player reconciliation and Arcade pre-run Your Color blanking are next-candidate work, not build-12 behavior. Current-profile-wins Game Center reassignment also requires the separate parent-PHP task before it can be described as end-to-end functional.
- **Prior compatible build:** TestFlight 1.2 (11).

### PimPoPom 1.2 (11) — 2026-07-27

- **Git source:** `9b3c2b6e5ee6055f66e9cd22cc171127e6a3f1c2` on `codex/testflight-1-2-build-11`; the exact release commit is also on `origin/main`.
- **Toolchain:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2.
- **Identity:** bundle `com.otcsoftware.pimpopom`; Apple Distribution team `APX2925X66`; Apple Sign In and Game Center entitlements; `get-task-allow = false`; marketing version/build `1.2 (11)`.
- **Verification:** `Scripts/check.sh` passed 29 deterministic core plus 219 native/unit/UI tests on the named iPhone SE (3rd generation) Simulator, 248 total with zero failures, skips, or expected failures. `git diff --check`, strict code formatting, asset/configuration/privacy guards, distribution signature inspection, and Apple archive validation passed. Result bundle: `/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hejlughidecerddzjroxolkasjul/Logs/Test/Test-PimPoPom-2026.07.27_15-37-28-+0200.xcresult`.
- **Archive:** `/Users/vlad/Documents/PimPoPom-release-artifacts/1.2-11/PimPoPom-1.2-11-9b3c2b6.xcarchive`; deterministic sorted-file manifest SHA-256 `d151aadede93ca93a0c80dd9ac5e32b8ea1aaf195af58e4082db2674c710b91d`.
- **Export:** `/Users/vlad/Documents/PimPoPom-release-artifacts/1.2-11/upload/PimPoPom.ipa`; SHA-256 `d23388f252688bd9f29dddc727ca079af653e11a4a574c33d151347af282becc`.
- **App Store Connect:** build `3a77fe90-fb8f-43e9-a850-41f256a08f85` processed `VALID`; icon present; `usesNonExemptEncryption = false`; Beta App Review `APPROVED`; Internal QA and External QA both `IN_BETA_TESTING` with automatic notification. The English beta description, per-build What to Test, and review notes were updated for the fresh Game Center verification and **See Stats** paths.
- **Runtime contracts:** every explicit Connect/Verify uses a new server challenge and GameKit proof for the current persistent player IDs. Runtime verification is memory-only and profile/player-scoped. PHP remains authoritative for protocol-verified Arcade ranking and achievement publication; the client never calls GameKit score or achievement submission APIs.
- **Known limitation:** physical TestFlight validation is still required for a successful clean Game Center link, asynchronous leaderboard/achievement delivery, Turn Off/reconnect/account switching, and the broader audio, ads, StoreKit, and accessibility matrix. Apple propagation can remain delayed after PHP accepts publication work.
- **Prior compatible build:** TestFlight 1.02 (10). The owner can expire a faulty TestFlight build while retaining the prior compatible backend and shipping a corrective binary.

### PimPoPom 1.02 (10) — 2026-07-25

- **Git source:** `68ad4d25e83ec98f4127e848c53543be1294f23e` on `codex/testflight-1-02-build-10`.
- **Toolchain:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2.
- **Identity:** bundle `com.otcsoftware.pimpopom`; Apple Distribution team `APX2925X66`; Apple Sign In and Game Center entitlements; `get-task-allow = false`; marketing version/build `1.02 (10)`.
- **Verification:** `Scripts/check.sh` passed 29 deterministic core plus 213 native/unit/UI tests on the named iPhone SE (3rd generation) Simulator, 242 total with zero failures, skips, or expected failures. `git diff --check` and App Store archive validation passed.
- **Archive:** `/Users/vlad/Documents/PimPoPom-release-artifacts/1.02-10/PimPoPom-1.02-10-68ad4d2.xcarchive`; deterministic sorted-file manifest SHA-256 `9487ac2c5d9f43e0dd698177df1c405e652c0bafa2d7d8b1c4a69342eb0bcfa2`.
- **Export:** `/Users/vlad/Documents/PimPoPom-release-artifacts/1.02-10/upload/PimPoPom.ipa`; SHA-256 `f61c09b5c90b36ff813983abd4c432eed5e3135ff1df67daa04361810d2186da`.
- **App Store Connect:** build `0e6f59d9-0cf2-4282-8f94-9d2ddbab2ca0` processed `VALID`; icon present; `usesNonExemptEncryption = false`; Beta App Review `APPROVED`; Internal QA and External QA both `IN_BETA_TESTING` with automatic notification.
- **Runtime contracts:** current Hostinger identity/Game Center response shape is compatible. PHP remains authoritative for protocol-verified Arcade ranking and achievement publication. StoreKit remains the accepted five-product catalog with server acknowledgement; Staging retains Google Mobile Ads 13.6.0, UMP 3.1.0, committed demo defaults, and owner-split Test mode routing.
- **Corrections:** primary sign-in now gates Game Center, retained GameKit authentication cannot leave Connect hanging, Connecting can be cancelled, ownership conflicts are explicit and non-merging, and enabled audio resumes after ordinary foreground restoration without bypassing genuine route/interruption gates.
- **Known limitation:** identities already owned by another internal UUID remain server conflicts, and stats cannot backfill until Game Center is linked to the exact owning primary profile or an audited server-side transfer/reset occurs. Physical TestFlight verification remains required for that recovery, Apple propagation, and audible app-switch behavior.
- **Prior compatible build:** TestFlight 1.02 (9). The owner can expire a faulty TestFlight build while retaining the prior compatible backend and shipping a corrective binary.

## Release record template

```text
Version/build:
Git commit/tag:
Xcode / Swift / SDK:
Archive checksum:
App Store Connect build:
API / ruleset / proof:
Economy / StoreKit catalog:
Ad / consent SDK:
TestFlight groups and evidence:
Physical device matrix:
App Store release time/state:
Backend deployment:
Prior compatible version:
Known limitations:
Rollback/halt owner:
```
