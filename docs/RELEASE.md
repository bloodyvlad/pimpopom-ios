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

### Repeatable TestFlight signing and upload commands

The established command-line lane uses a local Apple Development identity to create the archive, then lets App Store Connect re-sign the uploaded package for distribution. It does not require manually selecting a distribution certificate, and it does not launch a Simulator.

Keep the App Store Connect issuer ID, key ID, and `.p8` path outside Git. The key file must remain owner-readable only (`chmod 600`). This repository's credential names are `ASC_ISSUER_ID`, `ASC_KEY_ID`, and `ASC_PRIVATE_KEY_PATH`; their values must never be pasted into logs or committed.

If archive signing reports `errSecInternalComponent`, first verify and unlock the login keychain:

```sh
security find-identity -v -p codesigning
security unlock-keychain "$HOME/Library/Keychains/login.keychain-db"
```

Archive the exact clean commit with the release-optimized Staging scheme:

```sh
ARCHIVE="/absolute/release/path/PimPoPom.xcarchive"

xcodebuild \
  -project PimPoPom.xcodeproj \
  -scheme "PimPoPom Staging" \
  -configuration Staging \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  clean archive
```

Upload using the ignored App Store Connect API credentials:

```sh
EXPORT_DIR="/absolute/release/path/upload"

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist Config/ExportOptions-TestFlight.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_PRIVATE_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```

`Config/ExportOptions-TestFlight.plist` deliberately uses `destination = upload`, `method = app-store-connect`, automatic signing, symbol upload, and `testFlightInternalTestingOnly = false` so one processed build can serve both internal and external groups.

Before upload, inspect the archive rather than trusting project settings:

```sh
APP="$ARCHIVE/Products/Applications/PimPoPom.app"

plutil -p "$APP/Info.plist"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements :- "$APP"
find "$ARCHIVE" \( -name "*.p8" -o -name "*.storekit" -o -name "Local.xcconfig" \) -print
```

Retain the app dSYM with its UUID and SHA-256 after Apple accepts the build. The archive, export directory, DerivedData, and upload logs are reproducible and may then be removed to reclaim disk space; source, release record, API key, and retained dSYM are not disposable.

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

### PimPoPom 1.02 (20) Multiplayer identity polish — 2026-07-30

- **Git source:** `69fe7422719dd4953e90354a2ae3f3c976995db7` on `codex/multiplayer-avatars-build20`; the exact archived source is also on `origin/main`. This later release-record commit is documentation only and is not the archive identity.
- **Toolchain/identity:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2; bundle `com.otcsoftware.pimpopom`; team `APX2925X66`; Apple Sign In, Game Center, and iCloud container `iCloud.com.otcsoftware.pimpopom`; marketing version/build `1.02 (20)`.
- **Archive and symbols:** archived with the release-optimized **PimPoPom Staging** scheme at `/Users/vlad/Documents/PimPoPom-release-artifacts/1.02-20/PimPoPom-1.02-20-69fe742.xcarchive`; deterministic sorted-file manifest SHA-256 `8ed8bd8140547a858befeadc0bfa03a9c1dc1207c69fdb43b6f2677843e36516`. The reproducible archive, export directory, and project DerivedData were removed after App Store Connect acceptance. Retained app dSYM UUID `AC66885A-C79E-375E-A299-D8472AE8D7C1`: `/Users/vlad/Documents/PimPoPom-symbols/1.02-20/PimPoPom-1.02-20-69fe742-AC66885A-C79E-375E-A299-D8472AE8D7C1.dSYM.zip`, SHA-256 `0fb5c5ccdab44c7f1b9466cff8b5280edaa870f1be4eef7fe569f19ac4cf5510`.
- **Archive validation:** the exact clean commit resolved to version/build `1.02 (20)`, bundle `com.otcsoftware.pimpopom`, display name `PimPoPom`, and no embedded `.p8`, `.storekit`, or `Local.xcconfig`. Strict signature verification passed. The established local archive lane used Apple Development signing, including `get-task-allow`; App Store upload re-signed the package for distribution. Apple accepted the upload despite missing vendor-framework dSYM warnings for Google Mobile Ads UUID `90EDFF16-0A30-3944-A8D1-DC4FB9D1E710` and UMP UUID `3C3DB97D-600E-3898-906E-3AE471432865`; the app dSYM is retained separately.
- **Verification:** 47 focused Cosmetics and Multiplayer presentation tests passed, as did focused waiting-room and four-player live XCUITest paths across Classic, Disco, Light, and Pixel plus the Pixel glyph-off path and existing Pixel Leaderboard marketing fixture. Captures were inspected for half-right pet frames, square assigned-color cells, glyph settings, four-player fit, Pixel typography, themed navigation, and Leaderboard habitat alignment. Strict recursive `swift-format` lint and `git diff --check` passed. At the owner's explicit instruction, the final post-spacing UI rerun and full `Scripts/check.sh` gate were skipped; archive compilation and App Store processing are the final compile/distribution evidence.
- **App Store Connect:** build `a98b6bcf-1560-4c17-84cb-dffef47c0778` processed `VALID`; Beta App Review is `APPROVED`; automatic notification is enabled; Internal QA and External QA both report `IN_BETA_TESTING`. The English per-build What to Test begins **Multiplayer!!!**; the standing beta description and review notes were updated for this candidate. Approved build 19 remains assigned as rollback.
- **Presentation:** waiting-room and live Multiplayer identity surfaces show each selected pet in its half-right frame. Taller waiting rows move names clear of the pet and use a square game-cell color preview whose canonical glyph follows Settings. Pixel doubles the targeted small-copy sizes without changing other themes. Waiting Room uses Multiplayer typography, the back control is theme-styled and lowered five points, and Foka/Kesha receive a leaderboard-only seven-point habitat adjustment.
- **Trust/limitations:** PHP derives settlement from matching participant transcripts. Clean rows are **protocol-verified, peer-consistent**, not server-authoritative, human-verified, bot-proof, or collusion-proof. Simulator fixtures validate presentation and mocked behavior only. Real 2-, 3-, and 4-device/account GameKit matchmaking, peer timing, terminal settlement, leader transfer, leaderboard publication, and the final compact-device spacing adjustment remain physical/TestFlight acceptance work.

### PimPoPom 1.02 (19) Multiplayer layout release — 2026-07-30

- **Git source:** `95d9cde7f1b594208461b450b9023a5cec3fabc0` on `codex/multiplayer-layout-build19`; the exact archived source is also on `origin/main`. This later release-record commit is documentation only and is not the archive identity.
- **Toolchain/identity:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2; bundle `com.otcsoftware.pimpopom`; team `APX2925X66`; Apple Sign In, Game Center, and iCloud container `iCloud.com.otcsoftware.pimpopom`; marketing version/build `1.02 (19)`.
- **Archive and symbols:** archived with the release-optimized **PimPoPom Staging** scheme at `/Users/vlad/Documents/PimPoPom-release-artifacts/1.02-19/PimPoPom-1.02-19-95d9cde.xcarchive`; deterministic sorted-file manifest SHA-256 `16d93d1e1931553626d86f7965524f745e6d14601903480ec419f819f89d50d2`. The reproducible archive and project DerivedData were removed after App Store Connect acceptance. Retained app dSYM UUID `7A027C4C-FFE4-33B5-9695-C7033895D8F7`: `/Users/vlad/Documents/PimPoPom-symbols/1.02-19/PimPoPom-1.02-19-95d9cde-7A027C4C-FFE4-33B5-9695-C7033895D8F7.dSYM.zip`, SHA-256 `0b2b51de5b5cf57b08df12ac0e321cc9809921e8b38ec074dd2a04150ae70b3d`.
- **Archive validation:** the exact clean commit resolved to version/build `1.02 (19)`, bundle `com.otcsoftware.pimpopom`, display name `PimPoPom`, owner-split-test ad mode with official Google demo defaults plus the configured owner production units, and no embedded `.p8`, `.storekit`, or `Local.xcconfig`. Strict signature verification passed. The established local archive lane used Apple Development signing, including `get-task-allow`; App Store upload re-signed the package for distribution. Apple accepted the upload despite known missing vendor-framework dSYM warnings for Google Mobile Ads UUID `98EAF3D5-DC16-3F84-808A-86E09CCC12C2` and UMP UUID `69CD949A-53CD-3279-94A7-C81F18A1BA77`; the app dSYM is retained separately.
- **Verification:** all 52 deterministic core tests, the focused 14-test Multiplayer presentation suite, two focused XCUITest paths, and the complete 224-path native suite passed. The two UI paths ran only on the named iPhone 17 Simulator and covered the pet-free four-player waiting room plus four-player live Classic, Disco, Light, and Pixel layouts. `Scripts/check.sh` also passed project regeneration, strict formatting, `git diff --check`, resource/provenance checks, ad/configuration/privacy guards, generic Simulator compilation, and Staging release assertions. Focused UI result: `/tmp/PimPoPom-build19-layout-final-1785368813.xcresult`; screenshots: `/tmp/PimPoPom-build19-layout-final-attachments-1785369000/`; full result: `/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hejlughidecerddzjroxolkasjul/Logs/Test/Test-PimPoPom-2026.07.30_01-52-53-+0200.xcresult`.
- **App Store Connect:** build `81190b4a-a909-46c5-82b1-74055c47dc93` processed `VALID`; Beta App Review is `APPROVED`; automatic notification is enabled; Internal QA and External QA both report `IN_BETA_TESTING`. The English per-build What to Test begins **Multiplayer!!!**. Approved build 18 remains assigned as rollback.
- **Presentation:** the waiting room removes all pets, uses one full-size roster/control scale on compact and tall phones, and places the roster 20 points below its heading. Live play uses compact Points/Lives side cards around a large assigned-color cell and color name, with no redundant color caption and an exact 5-point HUD-to-board gap. The pet-free Speed Bar sits above a 44-point one-row player strip: 2–4 count-aware badges retain vertically centered pet art, compact score/name/multiplier typography, thicker assigned-color outlines, glow, and a top-right crown in every theme.
- **Trust/limitations:** PHP derives settlement from matching participant transcripts. Clean rows are **protocol-verified, peer-consistent**, not server-authoritative, human-verified, bot-proof, or collusion-proof. Simulator fixtures validate presentation and mocked behavior only. Real 2-, 3-, and 4-device/account GameKit matchmaking, peer timing, terminal settlement, leader transfer, and leaderboard publication remain physical/TestFlight acceptance work.

### PimPoPom 1.02 (18) Multiplayer settlement release — 2026-07-30

- **Git source:** `4352d93c1e62ccee20a5b650b585cf00ef7fa584` on `codex/multiplayer-readiness-leaderboard-fix`; the exact archived source is also on `origin/main`. This later release-record commit is documentation only and is not the archive identity.
- **Toolchain/identity:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2; bundle `com.otcsoftware.pimpopom`; team `APX2925X66`; Apple Sign In, Game Center, and iCloud container `iCloud.com.otcsoftware.pimpopom`; marketing version/build `1.02 (18)`.
- **Archive and symbols:** archived with the release-optimized **PimPoPom Staging** scheme at `/Users/vlad/Documents/PimPoPom-release-artifacts/1.02-18/PimPoPom-1.02-18-4352d93.xcarchive`; deterministic sorted-file manifest SHA-256 `0c2b82eef1f6e41ae28854ac5c1550c7742b2f2168b4b7b45c0e643f726b2999`. The reproducible archive and project DerivedData were removed after App Store Connect acceptance. Retained app dSYM UUID `5AED8ECE-B4CD-3890-8B7E-D3A42EC653C8`: `/Users/vlad/Documents/PimPoPom-symbols/1.02-18/PimPoPom-1.02-18-4352d93-5AED8ECE-B4CD-3890-8B7E-D3A42EC653C8.dSYM.zip`, SHA-256 `00ae30ecbeb078d7d43c683c7766bb3cf95a6174a7f9f0e64109aeccf4b53bc4`.
- **Archive validation:** the exact clean commit resolved to version/build `1.02 (18)`, bundle `com.otcsoftware.pimpopom`, display name `PimPoPom`, owner-split-test ad mode with official Google demo defaults plus the configured owner production units, and no embedded `.p8`, `.storekit`, or `Local.xcconfig`. Strict signature verification passed. The established local archive lane used Apple Development signing, including `get-task-allow`; App Store upload re-signed the package for distribution. Apple accepted the upload despite known missing vendor-framework dSYM warnings for Google Mobile Ads UUID `A33BA73A-EB40-3253-AE8F-650A005F413D` and UMP UUID `7AC81628-872D-383B-AB04-78BB42FFD908`; the app dSYM is retained separately.
- **Verification:** 52/52 deterministic core tests and the focused 28/28 Multiplayer backend/presentation/GameKit/peer-consistency suite passed. The complete `Scripts/check.sh` gate passed project regeneration, strict formatting, `git diff --check`, resource/provenance checks, ad/configuration/privacy guards, generic Simulator compilation, Staging release assertions, and all 223 native unit/UI paths with zero failures, skips, or expected failures. The full result bundle was `/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hejlughidecerddzjroxolkasjul/Logs/Test/Test-PimPoPom-2026.07.30_00-57-24-+0200.xcresult`.
- **App Store Connect:** build `b49ecbeb-92fe-4332-b9de-eb5969c7c933` processed `VALID`; Beta App Review is `APPROVED`; automatic notification is enabled; Internal QA and External QA both report `IN_BETA_TESTING`. The English per-build What to Test begins **Multiplayer!!!**; the beta description and review notes document terminal settlement, compact Multiplayer presentation, protocol-verified peer-consistent results, no Multiplayer coins/achievements, StoreKit Sandbox, and AdMob/UMP. Approved build 17 remains assigned as rollback while physical multiplayer checks begin.
- **Runtime correction:** iOS now orders every transcript event by tuple index 2, matching PHP's protocol chronology. A delayed final miss can therefore be followed by player-out and finish without being rejected before submission. The coordinator clamps terminal handled time to its reorder watermark and does not attempt a backward engine advance after finish. The exact seat-only submission is persisted for a bounded retry, callbacks are scoped to the active match, collecting state preserves provisional rows, and every participant remains on Results until terminal settled/review state.
- **Presentation:** the lobby and waiting room use the PimPoPom MP wordmark; promotional headings and the ordinary roster-loading card are removed; waiting/live players are stacked. Live play restores the compact Points/color/Lives HUD and shared pet-free Speed Bar. Full-width player badges use the HUD's 50-point height with pet left, score/name centered, large multiplier right, and crown over the upper-right corner. Compact iPhone SE geometry pulls the board toward the HUD and keeps a four-player waiting room's controls visible.
- **Trust/limitations:** PHP derives settlement from matching participant transcripts. Clean rows are **protocol-verified, peer-consistent**, not server-authoritative, human-verified, bot-proof, or collusion-proof. Real 2-, 3-, and 4-device/account GameKit validation remains required; build 18's exact terminal behavior and compact geometry are automated/mock-Simulator evidence until testers exercise the TestFlight binary.

### PimPoPom 1.02 (17) Multiplayer corrective release — 2026-07-29

- **Git source:** `07450a7f2877e306faacf647176f86c6c2604ae8` on `codex/multiplayer-readiness-leaderboard-fix`. This later release-record commit is documentation only and is not the archive identity.
- **Toolchain/identity:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2; bundle `com.otcsoftware.pimpopom`; team `APX2925X66`; Apple Sign In and Game Center entitlements; marketing version/build `1.02 (17)`.
- **Archive and symbols:** archived with the release-optimized **PimPoPom Staging** scheme at `/Users/vlad/Documents/PimPoPom-release-artifacts/1.02-17/PimPoPom-1.02-17-07450a7.xcarchive`; deterministic sorted-file manifest SHA-256 `441bd53a8f268225bc4a9119be86ebec62602647d49d2a7e3c43b710e92c4ec7`. The reproducible archive/export and project DerivedData were removed after App Store Connect acceptance. Retained app dSYM UUID `146234C3-66D2-3BA1-95CC-9638E81C05B3`: `/Users/vlad/Documents/PimPoPom-symbols/1.02-17/PimPoPom-1.02-17-07450a7-146234C3-66D2-3BA1-95CC-9638E81C05B3.dSYM.zip`, SHA-256 `408cc66607abfeac58c1df05c03b7254cb98e274e42105255eb57f5c55886e7c`.
- **Archive validation:** the signed archive resolved to version/build `1.02 (17)`, bundle `com.otcsoftware.pimpopom`, display name `PimPoPom`, owner-split-test ad mode with demo defaults, the intended Google configuration, and no embedded `.p8`, `.storekit`, or `Local.xcconfig`. Strict signature verification passed. App Store upload re-signed the package for distribution. Apple accepted the upload despite known missing vendor-framework dSYM warnings for Google Mobile Ads UUID `7AD92487-DDF5-3B47-ABCB-C1C44F697411` and UMP UUID `89DF15BA-CD36-3450-BBE8-0B14CBF9BCD2`; the app dSYM is retained separately.
- **Verification:** the focused readiness, Leaderboard, Profile parity, and Pixel presentation paths had passed before packaging. The final source also passed project regeneration, strict Swift formatting, `git diff --check`, asset/provenance checks, ad/configuration/privacy guards, generic-device Staging inspection, clean signed archive compilation, and archive validation. Per the owner's explicit instruction, no additional Simulator or physical-device test ran after the final corrective edits.
- **App Store Connect:** build `adafe302-d587-4999-8383-08524e84e707` processed `VALID`; icon present; `usesNonExemptEncryption = false`; Beta App Review `APPROVED`; Internal QA and External QA both `IN_BETA_TESTING`; automatic notification enabled. The standing beta description, English What to Test, and review notes document the corrected Ready flow, complete-roster/start gate, consolidated Leaderboard, eliminated-player spectating, synchronization/settlement, no Multiplayer coins/achievements, StoreKit Sandbox, and AdMob/UMP.
- **Runtime correction:** every participant can toggle PHP readiness before GameKit roster completion; roster matching and readiness errors are independent; creator Start still requires the complete confirmed roster plus every participant ready. Arcade, Zen, and Multiplayer now share one Leaderboard screen and one back control. The tabs say **Arcade**, **Zen**, and **Multiplayer**; Pixel labels no longer duplicate through shadows; player names retain readable width beside pet, color, readiness, and crown.
- **Retirement:** after build 17 reached `IN_BETA_TESTING` in both groups, builds 15 (`41cea27a-b807-42cc-914a-1c266fe941af`) and 16 (`0e66ff64-8f7e-4d04-a454-26f14926ed98`) were removed from Internal QA and External QA and explicitly expired.
- **Trust/limitations:** the unchanged Multiplayer transport still needs real 2-, 3-, and 4-device/account TestFlight validation. PHP derives clean settlement from peer-consistent transcript evidence; do not call it server-authoritative, human-verified, bot-proof, or collusion-proof. The Arcade ticket tuple remains build `20260729-1`, ruleset `reaction-proof-v3`, proof version 2.

### PimPoPom 1.2 (16) Multiplayer candidate — 2026-07-29

- **Git source:** `79b2e46523c1827fbd139d6bb09c56464c1c79a6` on `codex/multiplayer-build16`; the exact archived source is also on `origin/main`. This later release-record commit is documentation only and is not the archive identity.
- **Toolchain/identity:** Xcode 26.6 (`17F113`), Apple Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2; bundle `com.otcsoftware.pimpopom`; team `APX2925X66`; Apple Sign In and Game Center entitlements; marketing version/build `1.2 (16)`.
- **Archive and symbols:** archived with the release-optimized **PimPoPom Staging** scheme from `/Users/vlad/Documents/PimPoPom-release-artifacts/1.2-16/PimPoPom-1.2-16-79b2e46.xcarchive`; deterministic sorted-file manifest SHA-256 `a27e1be8718ba035602446a757eb779d2b4acdd9cb916d0f93bb99097f3f3a54`. App Store upload re-signed the package for distribution. Retained dSYM: `/Users/vlad/Documents/PimPoPom-symbols/1.2-16/PimPoPom-1.2-16-79b2e46-7C6FC5C3-722C-3909-A826-1886312884C7.dSYM.zip`, SHA-256 `1ea1303be17dfa4d6685420dfd5eda3275784912c2a0af1b63d65e6019010272`. The disposable local archive/export was removed after acceptance.
- **Backend dependency:** Hostinger backend release `20260729-1`; `/api/mobile/v1/multiplayer`; `multiplayer-own-color-v1`; protocol/proof version 1; 2–4 own-color players; no coins or achievements. A post-upload signed-out `GET /api/mobile/v1/multiplayer/leaderboard` smoke read returned HTTP 200 and the expected empty Multiplayer board shape; authenticated writes were not performed.
- **Verification:** 52/52 deterministic core tests, 36/36 focused Multiplayer service/transport/presentation tests, and the complete 214/214 native test target passed on the single named iPhone 17 Simulator with iOS 26.5. `Scripts/check.sh` also passed project regeneration, strict formatting, resources/provenance, ad/configuration/privacy guards, a generic Simulator build, and Staging release assertions. The inspected full result bundle was `/Users/vlad/Library/Developer/Xcode/DerivedData/PimPoPom-hejlughidecerddzjroxolkasjul/Logs/Test/Test-PimPoPom-2026.07.29_17-37-50-+0200.xcresult` before DerivedData cleanup.
- **App Store Connect:** build `0e66ff64-8f7e-4d04-a454-26f14926ed98` processed `VALID`; icon present; `usesNonExemptEncryption = false`; Beta App Review `APPROVED`; Internal QA and External QA both `IN_BETA_TESTING` with automatic notification enabled. The standing beta description, English What to Test, and review notes cover Multiplayer prerequisites, synchronization/recovery/settlement, no coins or achievements, and eliminated-player spectating through the final peer.
- **Runtime:** adds available-lobby/create/join/refresh, capacity selection, readiness and draggable-pet waiting room, exact `playerGroup` GameKit matchmaking, unanimous roster/coordinator confirmation, fixed-coordinator reliable live packets/snapshots, synchronized board/player strip/pets/crown/tones, compact transcript retention, exact submission retry, settlement/results, and Multiplayer leaderboard surfaces. A player with zero lives becomes a noninteractive spectator while receiving the complete event stream until every participant is out.
- **Game Center transport:** sender-to-seat/color identity is frozen after roster confirmation; every accepted input retains all-peer evidence; final submission refuses unexplained or missing evidence. Protocol v1 uses a fixed coordinator, bounded recovery, and no host migration.
- **Game Center leaderboard:** app Apple ID `6792328590`; vendor ID `com.otcsoftware.pimpopom.multiplayer.verified`; leaderboard resource `2b03eb62-0107-431d-b4dc-347317e10dc2`; leaderboard version `c582d3da-76c9-44a2-86f8-4b135f73185a`; localization `d000beaa-8a4d-4435-9186-e117ab4cfefb`.
- **App-review association:** add-only association exists on draft review submission `8069f585-f7a1-4a4e-833a-0b90ce3d0f8f`; review item `ODA2OWY1ODUtZjdhMS00YTRlLTgzM2EtMGI5MGNlM2QwZjhmfDEyfGM1ODJkM2RhLTc2YzktNDRhMi04NmY4LTRiMTM1ZjczMTg1YQ`; component and item reported `READY_FOR_REVIEW`. The draft has not been submitted (`submittedDate` is null); this is not App Store approval, production release, or TestFlight evidence.
- **Trust/limitations:** PHP replays matching transcripts and may publish each verified personal best; iOS never publishes directly. Clean rows are **protocol-verified, peer-consistent**, not server-authoritative, human-verified, bot-proof, or collusion-proof. No real 2-, 3-, or 4-player physical/TestFlight GameKit match has been completed yet; peer latency, multi-device audio, background recovery, unanimous production settlement, and Apple leaderboard publication remain unvalidated. Failed exact recovery cancels/forfeits.
- **Prior compatible build:** TestFlight 1.2 (15).

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
