# TestFlight and App Store release

Production submission, live-ad activation, and paid-product activation require
explicit owner authorization. A TestFlight approval is not an App Store release.

## Current candidate, beta, and rollback

| Item | Current truth |
| --- | --- |
| Current beta | `1.02 (25)`, uploaded 2026-09-09; VALID |
| App Store Connect build | `b8afe802-32d4-4538-aaf1-b27182693653`; external-eligible, non-exempt encryption false |
| Groups / external state | Internal QA and External QA both `IN_BETA_TESTING`; beta review `APPROVED` |
| Uploaded source | `962a39de80277534dd45eca56ca913217bde1fbb`, clean Staging archive/export |
| Hosted backend | Railway Amsterdam v2 and PHP bridge/migration 023 deployed; boundary checks passed |
| Rollback beta reference | Build 20, source `69fe7422719dd4953e90354a2ae3f3c976995db7`; current installability not reverified |
| Authorized work | Railway EU service, separate PHP v2 bridge/migration 023, TestFlight Internal QA/External QA; no paid-plan upgrade or App Store production submission |
| Production App Store | No production release established by this task |

Real signed-in 2/3/4-device matches, 60/120 Hz acceptance and public legal URLs
remain open. Build 24 remains the historical GameKit/v1 binary.

## Build 25 evidence

| Item | Verified value |
| --- | --- |
| Source branch | `codex/railway-eu-testflight`; uploaded source SHA above, later documentation commits are not new binaries |
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
   production submission. The owner authorized this QA upload on 2026-09-09 after
   the Railway service and required PHP bridge are aligned.

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
