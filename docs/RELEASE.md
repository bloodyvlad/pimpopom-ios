# TestFlight and App Store release

Production submission, live-ad activation, and paid-product activation require
explicit owner authorization. A TestFlight approval is not an App Store release.

## Current candidate, beta, and rollback

Build 28 is implemented locally; PHP `f84dc921` was deployed first on 2026-09-11
to **speedytapper.otcsoft.com** only. All 69 source hashes and 35 HTTPS checks pass;
v3/v4/v5 admission works, schema 024/private config/original workers are unchanged.
Exact artifact/rollback evidence is retained in
`/Users/vlad/Documents/SpeedyTapper-release-artifacts/20260911-arcade-v5.mTFG0j/RELEASE.md`.
Railway and TestFlight remain pending until the new release record replaces this
candidate note. Existing Apple state below is the verified build-27 baseline.

| Item | Current truth |
| --- | --- |
| Current beta | `1.02 (27)`, uploaded 2026-09-10; VALID |
| App Store Connect build | `9e0b4ce6-ea42-4d75-b7f6-b5201932665d`; external-eligible, non-exempt encryption false |
| Groups / external state | Internal QA and External QA both `IN_BETA_TESTING`; beta review `APPROVED` |
| Uploaded source | `753787005b2773e93d02e319ad3713847cf4db0d`, clean Staging archive/export |
| Hosted backend | Railway Amsterdam revision 2 unchanged; PHP v4 verifier `0a94f5c` deployed, schema 024 unchanged; boundary checks passed |
| Prior beta / rollback reference | Build 26, source `6a94d64312b113c8013782aca0a3ea8c8718eaf9`, still VALID and assigned to both QA groups when checked |
| Authorized work | Multiplayer fixes, Railway/PHP alignment and TestFlight Internal QA/External QA; no paid-plan upgrade or App Store production submission |
| Production App Store | No production release established by this task |

Real signed-in 2/3/4-device matches, 60/120 Hz acceptance and public legal URLs
remain open. Build 24 remains the historical GameKit/v1 binary.

## Build 27 evidence

Direct Apple verification on **2026-09-10** confirmed VALID,
`APP_STORE_ELIGIBLE`, beta review APPROVED and both existing QA groups
`IN_BETA_TESTING`. en-US What to Test and reviewer notes were updated. Existing
contacts, demo-account settings, public link and automatic notifications were
preserved; no duplicate notification was sent.

| Item | Verified value |
| --- | --- |
| Branch / binary source | `codex/build27-powerups-release` / `753787005b2773e93d02e319ad3713847cf4db0d` |
| Configuration | PimPoPom Staging, iOS 17+, `-O`, whole-module, `STAGING` without `DEBUG`, existing owner-split test ads |
| Archive TGZ SHA-256 | `e49dec84e2ac30ecb635930a18c3cfa00fd8fa91836ec6127db87fa63741bec3` |
| 115-file manifest SHA-256 | `975be843ba67f3f58c420ca262439b9d59217f60d98fdaf0887a8174cd2bc1b3` |
| App/dSYM UUID | `AF31E400-575D-3B3E-B1D7-B5FD3426A1C7` |
| App binary SHA-256 | `47f59d62b4debe054092cc727a05a23589d39bbd011be2e225e268fc2322df08` |
| App dSYM SHA-256 | `00c84a289819010b147c3686ab11c0fb0ddd2a77210757ca465a18ec3738c939` |
| Apple upload / expiration | 2026-09-10 21:19:08 UTC / 2026-12-09 21:19:08 UTC |
| Deployed PHP source | `0a94f5cfe2a36ae89f0d26db1c72bf7cfe4d683c`; exact clean isolated source, no migration/season change |
| PHP artifact SHA-256 | `3e9ad75ff087388038374be64846fe2b3f77ad2ac503379c13f651344cee6d9a` |

Archive/export/upload succeeded. App signature and symbols match; 12 privacy
manifests and no prohibited files. Export applied distribution signing with task
allowance disabled. Apple accepted the same GoogleMobileAds/UMP missing-dSYM
warnings as build 26; app-owned symbols are retained.

Final source passed **234 app/UI tests, zero failures/skips, and 84 core tests**.
The initial pickup hittability failure was fixed with stable accessibility cell
identities; the original Simulator board-contact assertion remains. Its regression and
focused pickup test passed, then the full gate passed. Prior feature verification
includes 26 service tests and a 92-second four-client color/heart scenario.

PHP was deployed before upload: 69 deployed source hashes matched; direct schema
024/private-configuration status and 35 live HTTP checks passed. Local PHP tests
include 111 v4 SQLite, 112 MariaDB and 72 full persisted-path assertions. Ten live
WSS boundary checks passed; Railway was not redeployed. No live player result,
physical-device latency or four-iPhone match is implied by these checks.

Artifacts and exact Apple state are retained under `build/releases/build27-20260910/`.
Backend release/rollback evidence is at
`/Users/vlad/Documents/SpeedyTapper-release-artifacts/20260910-arcade-v4.fgRKTb/`.
The original PHP checkout was untouched. Code-only PHP rollback to 9fe555d retains
schema 024 but cannot complete v4 runs: coordinate with build-27 availability,
never restore account data or downgrade schema. Build 26 works with the new PHP;
builds 26/27 share revision-2 multiplayer rooms.

## Historical build 26 evidence

Direct Apple verification at **2026-09-10 19:40:39 UTC** confirmed VALID,
`APP_STORE_ELIGIBLE`, beta review APPROVED and both existing QA groups
`IN_BETA_TESTING`. The en-US What to Test and reviewer notes were updated;
contacts, demo-account settings and existing public-link settings were preserved.
`autoNotifyEnabled=true`; no duplicate manual notification was sent.

| Item | Verified value |
| --- | --- |
| Branch / uploaded source | `codex/mp26-gameplay-release` / `6a94d64312b113c8013782aca0a3ea8c8718eaf9`; subsequent docs commits do not change the binary |
| Toolchain | Xcode 26.6 (17F113), Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.6.2 |
| Configuration | PimPoPom Staging; iOS 17+, `-O`, whole-module, `STAGING` without `DEBUG`; owner-split test ads |
| Archive TGZ SHA-256 | `5fe13c1c30be52a84522b0c4ef47ea7a6bc3f204240026b774f897e86a93a45d` |
| 115-file archive manifest SHA-256 | `516712c07b124e07354f1d681f3101ec7e87a39f3bbfbcca885bf16b4c0536d8` |
| App and matching dSYM UUID | `31442D1A-D3CD-3472-8429-171A1AA0D80B` |
| App binary SHA-256 | `ff61d3ea8b135d90074525dff261c847a8922dad9955506a262cde25fb16a29f` |
| App dSYM SHA-256 | `3e10fe673478b0e89eefa9ff7f98fb2ab80447cf11f426d6fb1c6fd724a95052` |
| Apple upload / expiration | 2026-09-10 19:38:15 UTC / 2026-12-09 19:38:15 UTC |
| Deployed Railway source | `6629fe09f31d34584ec39e49e99b49633bf035ea`; later iOS lifecycle-only change leaves deployed Server/Core identical |
| Deployed PHP source | `9fe555d179326cecd5e23f0a6a16788b4af0ba34`; additive 024 applied, season-1 unchanged |

`ARCHIVE SUCCEEDED`, `Upload succeeded` and `EXPORT SUCCEEDED` were verified.
Signature and app symbols match; twelve privacy manifests and zero prohibited
files were found. Distribution export disabled task allowance. Apple accepted
GoogleMobileAds/UserMessagingPlatform missing-dSYM warnings; third-party crash
symbolication can be incomplete, while the matching app-owned dSYM is retained.

Final clean source passed **225 app/UI tests (220 unit + 5 UI), 72 core tests and
26 service tests**, with zero app/UI failures or skips. Service/core Linux checks,
local 2/3/4-client sockets and a 43-second heart/color/decoy gameplay check passed.
Hosted service verification covered runtime identity, writable persistent storage,
ten WSS boundary cases and 35 PHP boundary checks. This is not physical-device
latency or positive signed-in internet-match evidence.

Artifacts are retained under `build/releases/build26-20260910/`, including
`PimPoPom-build26-final.xcresult`, the final archive TGZ, `apple-final-state.json`,
What to Test, private upload logs, source manifests and backend evidence. The
earlier local build-26 archive is marked superseded and was never uploaded.
The [Railway deployment record](../Server/DEPLOYMENT_RAILWAY.md) contains exact
hosted artifact and rollback identities. Both players must install build 26 to
exercise the new gameplay; build 25 uses separate compatible revision-1 rooms.

## Historical build 25 evidence

| Item | Verified value |
| --- | --- |
| Source branch | `codex/railway-eu-testflight`; uploaded source `962a39de80277534dd45eca56ca913217bde1fbb`, later documentation commits are not new binaries |
| Toolchain | Xcode 26.6 (17F113), Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.6.2 |
| Configuration | PimPoPom Staging; iOS 17+, `-O`, whole-module, `STAGING` without `DEBUG`; test ads |
| Archive TGZ SHA-256 | `915eee26aa49000f0c436c4197afca02892f5aa8642ae308c41434d8421e4e80` |
| 115-file archive manifest SHA-256 | `8152484990ce751f239c713baca9f12c0a11972b733b4faa114ccb6d7e959a2d` |
| App and matching dSYM UUID | `7C5E3C9F-8EBE-3B5E-91A3-FD52FBAC634D` |
| App dSYM SHA-256 | `fbea81ff4973bc6ff5ae95b30b1ff9d32eb895f2fcf44c25eca601fa0c1a15be` |
| Apple upload timestamp | 2026-09-09 15:41:07 UTC |
| Expiration reported by Apple | 2026-12-08 15:41:07 UTC |

`ARCHIVE SUCCEEDED`, `Upload succeeded`, `Uploaded package is processing`, and
`EXPORT SUCCEEDED` were verified. The app signature and matching symbols passed;
no `.p8`, `.storekit`, local config, test fixture directory or credential file was
found in the archive. Twelve privacy manifests were present. The automatic-signing
archive used development entitlements; App Store export selected distribution
signing and disabled task allowance. Apple reports `APP_STORE_ELIGIBLE`, not an
internal-only upload, and `usesNonExemptEncryption=false`.

GoogleMobileAds and UserMessagingPlatform dSYMs were not included in the archive.
Apple accepted the upload with warnings; app-owned symbols are retained,
but third-party crash symbolication can be incomplete. No vendor symbols were
fabricated. The unrelated AppIntents extraction warning is non-blocking.

Release artifacts and passing logs are under `build/releases/build25-20260909/`.
The retained `PimPoPom-build25.xcresult` directly confirms 209 app/UI tests passed
with zero failures/skips, including the native loopback socket test and four UI
checks, on PimPoPom iPhone 17 / iOS 26.5 Simulator. Shared-core tests passed 63;
service tests passed 11 on macOS and Linux. No physical-device claim is made.
Private archive/upload logs stay outside Git with owner-only access. Server image,
outbox restart, PHP artifact/migration, backup and rollback evidence is in the
[Railway deployment record](../Server/DEPLOYMENT_RAILWAY.md).

The en-US What to Test, beta description and reviewer notes were updated for v2.
Existing contact details and the external group's public link were preserved.
Both original QA groups were assigned build 25 after it became VALID. Beta review
submission was accepted, then a direct follow-up read around 16:01 UTC reported
`APPROVED`, internal `IN_BETA_TESTING` and external `IN_BETA_TESTING`.
`autoNotifyEnabled=true` was preserved; no duplicate manual notification was sent.
Public privacy-policy/support URLs are still missing; the owner has been asked
for actual URLs. Reviewer notes honestly describe Apple/Google self-registration
and the two-device requirement, with no invented demo credentials. API-reported
beta approval does not establish a real-device match or production approval.

## Release identity record

For every archive record:

- exact source commit/tag and clean status;
- marketing/build number and App Store Connect ID/state;
- Xcode, Swift, SDK, macOS, and resolved package versions;
- bundle, team, configuration, signing, capabilities, and environment;
- API/build/ruleset/proof, catalog, StoreKit, ads, and consent versions;
- archive manifest/checksum, signature/entitlement inspection, and retained dSYM;
- automated/Simulator/physical/TestFlight evidence and explicit gaps;
- previous supported build and backend compatibility rollback.

## Pre-archive gate

1. Start from an exact clean reviewed commit; run `Scripts/check.sh` and
   `git diff --check`.
2. Confirm generated project, package lock, asset hashes/licences, strict formatting,
   generic-device build, UI/unit suite, privacy/configuration checks, and version.
3. Verify deployed Arcade compatibility and the candidate's exact v2 protocol,
   PHP ticket/service-auth/result bridge, WSS endpoint and persistent outbox.
   Separately preserve historical v1/rollback backend compatibility. Local code
   or migration tests do not prove those services are deployed.
4. Inspect archive Info, entitlements, signature, aggregate privacy report, symbols,
   asset catalog, and absence of `.p8`, `.storekit`, ignored config, debug fixtures,
   and credentials.
5. Confirm public Privacy/Support/account-deletion/Terms URLs, seller/rights, export,
   age, privacy, IAP, Game Center, ads/UMP, and reviewer metadata.
6. A TestFlight QA candidate may upload with physical gates explicitly open. Complete
   real 2/3/4-device and latency/loss/reorder acceptance before v2 acceptance or
   production submission. The owner authorized build 26 QA distribution on
   2026-09-10; the Railway service and required PHP bridge were aligned first.

### Configuration gates

- Debug uses official demo ads.
- Staging is release-optimized TestFlight against the shared Hostinger compatibility
  service. It is not an isolated backend. Owner fingerprints select production units
  only with registered Test mode; every other install uses demo units.
- Owner Ads QA is cable-only and every creative must visibly say **Test mode**.
- Checked-in Release is disabled. Live ad values require ignored private config and
  explicit authorization; no test identifier may coexist.
- Local StoreKit fixtures never enter an archive. TestFlight uses Sandbox StoreKit.
- iOS never directly submits Game Center scores/achievements.

## Archive and upload

Archive the exact clean commit with the release-optimized **PimPoPom Staging**
scheme for named TestFlight QA. Use ignored App Store Connect API credentials and
the committed `Config/ExportOptions-TestFlight.plist`; never print or commit their
values. Before upload inspect:

```sh
plutil -p /absolute/archive/PimPoPom.xcarchive/Products/Applications/PimPoPom.app/Info.plist
codesign --verify --deep --strict --verbose=2 /absolute/archive/PimPoPom.xcarchive/Products/Applications/PimPoPom.app
codesign -d --entitlements :- /absolute/archive/PimPoPom.xcarchive/Products/Applications/PimPoPom.app
find /absolute/archive/PimPoPom.xcarchive \( -name '*.p8' -o -name '*.storekit' -o -name 'Local.xcconfig' \) -print
```

Do not claim success until App Store Connect completes processing. Retain the exact
source/release record and app dSYM with UUID/hash. Archive/export/DerivedData may be
removed only after reproducibility and acceptance are recorded.

## TestFlight and production progression

Internal testing covers install/update/reinstall, modes, identity, ranked proof,
Game Center, leaderboards, achievements/cosmetics, audio/haptics, UMP/Test-mode ads,
StoreKit, restore, deletion, and Multiplayer. External beta expands device/OS/
locale/network coverage and monitors crashes, hangs, energy, purchase/API/proof
review rates. Use named groups; a public link requires a separate decision.

Production submission additionally requires complete metadata/screenshots, IAP
review media, live public legal URLs, archive-derived privacy answers, seller/rights
clearance, final backend smoke tests, and explicit owner approval. After release,
verify download/update, modes, identity/deletion, ranking, Game Center publication,
payments/refunds, entitlement-driven ad removal, consent, and service health.

## Halt and recovery

Stop rollout for crash/login loops, data corruption, uncredited payment, paid-value
loss, backend incompatibility, privacy/security incident, unsafe ads, or invalid
Multiplayer settlement. Apple has no instant binary rollback: halt phased release
where available, keep the prior client/backend compatible, disable risky server
features safely, submit a corrective build, and reconcile immutable purchase/result
evidence rather than deleting it.
