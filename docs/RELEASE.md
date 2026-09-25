# TestFlight and App Store release

## Build 35 — TestFlight active and public review submitted (2026-09-25)

Version **1.02 (35)**, exact clean source `8bcf9b32c6fdb192222a615795e8fc666fa26aab` on
`codex/review-shop-onboarding35`. [PR #3](https://github.com/bloodyvlad/pimpopom-ios/pull/3)
adds shop sign-in routes and automatic player setup to the age/ATT history merged
into main by PR #2 at `ec46335745d85495f786c5c52a0425f9f33c6edf`.
Evidence-only follow-up commits do not change the uploaded binary.

| Evidence | Verified value |
| --- | --- |
| Apple app / version | 6792328590 / 5037e930-61ad-41b8-b8a1-6ecddd3288a8 |
| Apple build | 88078b6e-7d5d-480d-ae3c-304b3e23a02a — VALID, APP_STORE_ELIGIBLE, exempt encryption |
| TestFlight | Internal QA and External QA IN_BETA_TESTING; beta review APPROVED; automatic notification enabled |
| Public submission | 2d700cdb-2d54-4f0a-b431-ff3d3b84ea94 — 13 items, WAITING_FOR_REVIEW |
| Submitted | 2026-09-25T12:33:05.436Z |
| Release policy | AFTER_APPROVAL; not publicly released yet |
| Toolchain | Xcode 26.6 (17F113), iOS 26.5 SDK, optimized Release, iOS 17 minimum |
| Archive manifest SHA-256 | `f1a1186e85d031e788d216e8f0d82ea6bcb959f11ba131aac1520ba88e3d3b4a` |
| Reviewed signed local IPA SHA-256 | `56990b83db2acbc5a162b06b0ba2b0ecde707f271bddf1926f982f0166e7c72b` |
| App / dSYM UUID | `813A7777-4E9D-3C26-90A5-9FC9090FE5F8` |
| dSYM SHA-256 | `c6c8a6b96c5686cc89756fa911741bccb4898ab220bc612effb455c55f8df664` |

Four focused shop/navigation and generated-name checks passed on iPad simulator;
iPhone screenshots and iPad launch were inspected. No gameplay tests, transactions,
or physical-device validation. [Scope and latency findings](APP_REVIEW_FIX_35.md).
The export was re-extracted and inspected: valid distribution signature, no debug
entitlement, live ads without test/owner overrides, ATT purpose/framework retained,
12 unchanged vendor/application privacy manifests, and matching app symbols.
Apple again warned about absent prebuilt GoogleMobileAds/UMP vendor dSYMs; upload
and VALID processing succeeded. Vendor framework crash symbolication is limited.

The rejected build-34 submission `57f9deb0-e40f-4d17-b634-d25a4779c92e` was completed
by removing its 13 review items; the same five IAPs, two leaderboards and five
achievements were retained in the new submission. Apple needed a short propagation
delay before those removed companion items could be reattached. Official API
readback confirms the new version/build relationship, all 13 items and review state.
Review notes and en-US TestFlight What to Test were updated. Storefront copy,
media, availability, prices, age declarations and consent configuration were retained.

No PHP/Railway deployment or schema/protocol change occurred. The existing build-34
backend tuple is retained, not newly gameplay-validated. Build 34 remains available
as a reference beta; it is rejected for public review and is not an approved public
fallback. No beta build was expired. Temporary production ad overrides were removed.
Private evidence: `~/.local/share/pimpopom-releases/20260925-review35/release35-receipt.json`.
Unrelated dirty files in the original iOS checkout were preserved.

## Build 34 — TestFlight active and public review submitted (2026-09-19)

Version **1.02 (34)**, exact clean source `0a03dac07006b537c449bacbee9bf49607959a9d` on
`codex/app-review-att34`. [Review diff](https://github.com/bloodyvlad/pimpopom-ios/pull/2)
is based on the already-uploaded build-33 branch. Later evidence-only commits do
not change this uploaded binary.

| Evidence | Verified value |
| --- | --- |
| Apple app / version | 6792328590 / 5037e930-61ad-41b8-b8a1-6ecddd3288a8 |
| Apple build | 6b41eb06-b6cf-483b-a7b7-952532e08cba — VALID, APP_STORE_ELIGIBLE, usesNonExemptEncryption=false |
| TestFlight | Internal QA and External QA IN_BETA_TESTING; beta review APPROVED; automatic notification enabled |
| Public submission | 57f9deb0-e40f-4d17-b634-d25a4779c92e — 13 items, WAITING_FOR_REVIEW |
| Submitted | 2026-09-19T19:18:15.491Z |
| Release policy | AFTER_APPROVAL; not publicly released yet |
| Toolchain | Xcode 26.6 (17F113), optimized Release, iOS 17 minimum |
| Archive manifest SHA-256 | `2fe5e4510ba5cf41498d7f499323a687590a891564bb53295b20f7e124e89f88` |
| Reviewed signed local IPA SHA-256 | `48636d54f0fde1c453473605c354e40cf8eecc66884c82df2d3b4810e511b049` |
| App / dSYM UUID | `51F8216C-F1CF-33CD-A20A-FBD95B36417C` |
| dSYM SHA-256 | `c470a15232a05f48f0aed7f2f797f491e38fd59dba7fbde883be13d9a3c09383` |

The reused rejected submission was briefly resubmitted through the API, but its
review page still displayed build 33 despite the version API linking build 34.
It was canceled (COMPLETE) and replaced with the fresh submission above. The
new draft visibly showed 1.02 (34) and the same 13 items before submission.
After submission, Firefox and the official API both confirmed build 34 and
Waiting for Review on the new submission.
The original rejection message remains on submission
`c75ba21e-c5f2-431b-ac51-e450e088ec9b`; new review notes explain both fixes.

Upload completed from the inspected immutable archive. Freshly extracted local
export has a valid distribution signature, no debug entitlement, ATT purpose and
framework, live AdMob units, empty test/owner fields, no consent-test hooks and
12 reconciled privacy manifests. App symbols match; Apple warned that the
prebuilt GoogleMobileAds/UMP packages omitted their vendor dSYMs. Those warnings
did not prevent VALID processing or beta approval; vendor crash symbolication
remains limited.

Only launch/age/consent validation was run on iPhone 17 and iPad Air 11-inch (M3)
simulators (iOS 26.5). No gameplay tests or physical-device validation. Exact
scope, failed harness attempts, corrected checks, privacy/age metadata and
published legal 1.0.2 evidence are in [APP_REVIEW_FIX_34](APP_REVIEW_FIX_34.md).
No PHP, Railway, schema, StoreKit product or gameplay change/deployment occurred;
existing build-33 backend/protocol configuration is retained, not newly live-tested.
Build 33 remains available as a reference beta, but its privacy rejection makes
it unsuitable as a public-release fallback. No previous beta was expired.

Private receipt: `~/.local/share/pimpopom-releases/20260919-att34/release34-receipt.json`.
The task's temporary production xcconfig was removed after upload; checked-in
Release remains disabled until a separately authorized archive supplies live IDs.
Unrelated dirty worktrees, including the original legal source, were preserved.

Production submission, live-ad activation, and paid-product activation require
explicit owner authorization. A TestFlight approval is not an App Store release.

## Build32 authorized preparation

The owner authorized uploading build32 to TestFlight and submitting the same
binary for public review. This source note does not assert completion; exact clean
commit, signed archive/export checks, hashes and Apple identifiers are retained in
`~/.local/share/pimpopom-releases/20260912-production32`. Build31 artifacts remain
unchanged. Only age/consent checks are authorized now; physical/manual QA is deferred.
See [candidate32](PRODUCTION_CANDIDATE_32.md).

## Historical build29 beta and rollback

Build **1.02 (29)** is VALID / `APP_STORE_ELIGIBLE`. Direct Apple verification at
**2026-09-11 19:02:18 UTC** confirmed beta review **APPROVED** and both existing
Internal QA / External QA groups **IN_BETA_TESTING**, with automatic notification
enabled. Existing public link and all standing contact/demo/URL fields were
preserved; en-US What to Test, beta description and review notes were updated.

| Item | Verified value |
| --- | --- |
| Binary source / branch | `199bf48f6dccbc0b1a3b234dc12aca3977c16a50` / `codex/build29-gameplay-release` |
| Apple build | `f8c2710e-c0c6-42be-a570-a18145271a59` |
| Apple upload / expiration | 2026-09-11 18:59:59 UTC / 2026-12-10 18:59:59 UTC |
| Configuration | Optimized Staging without DEBUG, iOS 17+, unchanged owner-split test ads |
| Archive TGZ SHA-256 | `6422500dc9e5d2eb361094ab2ae2b41af833c692a010d9c9a3f9c4b07c5c3462` |
| 115-file manifest SHA-256 | `c026f770e9b4719dda55fe9b3e4f9dd767874146cd1ca04cc8c91aed6eed2d9f` |
| Matching app/dSYM UUID | `1831F4E0-9BA8-365C-AA2A-0B6785D9FE41` |
| App binary SHA-256 | `075f08ec208984e194b7130f978d051e4309f6e0c1eb3fb4eb738aa8ee04aba3` |
| Railway source / deployment | `9b28b210e44919cb6d1719ffb97054ab35764de1` / `9ec61784-391e-4be0-bdbe-deb227487f69`, SUCCESS |
| PHP source | `bf0ef1b030772872775ab64eaedcbaa1b256e0cf` |
| PHP artifact SHA-256 | `2646c77801a5ac8005f916a05666874a11d0426e05fd257720390aeb420079b1` |
| PHP schema / target | Additive 025 applied; only `speedytapper.otcsoft.com`; season and purchased value preserved |

Actual order: PHP was deployed and verified first (73 source hashes, schema
001–025, unchanged private configuration/workers, 45 HTTPS boundaries). Railway
upload/build started next. The owner explicitly authorized iOS upload while
Railway was compiling; the upload command started around 18:57 UTC, followed by
successful fresh Railway runtime verification around 18:58. iOS export/upload
succeeded at 18:59:11; Apple's resource records upload at 18:59:59. Do not imply
the Railway runtime gate had completed before the iOS upload command began.

Railway native x86_64 build/runtime and 13 negative WSS/auth boundaries passed:
UID/GID 10001, NoNewPrivs, private 0700 writable outbox, unchanged Amsterdam instance,
volume, configuration and variable fingerprints. Temporary pinned SSH access was
removed. Health advertises ranking for gameplay revision 3 / result revision 2.
These checks made no real player/result/reward writes and do not prove a positive
hosted match or reward settlement. [Detailed service evidence](../Server/DEPLOYMENT_RAILWAY.md).

**UI QA exception:** the initial native gate ran 265 tests: **259 passed, six UI
failures, zero skipped**; native unit tests passed. A focused three-test run passed
badge layout and privacy, but failed clock-stamp feedback on the pre-ZStack build.
Tutorial accessibility (`b3b1473`) and stable stamp-host (`199bf48`) corrections
were not Simulator-retested, per the owner's explicit no-recheck request. Final
compact/all-theme tutorial and pickup acceptance is incomplete. This is **not a
fully green final-source UI gate**; archive success is not substitute UI evidence.

Exact shared source separately passed 95 core/47 service tests on macOS and Linux
ARM64 and real local socket scenarios. PHP Composer, 94 reward/ranking and 154
retained Arcade MariaDB assertions passed. No local AMD64 unit-test or physical
device/60–120 Hz/real-account reward acceptance is claimed.

The clean archive signature, matching app-owned symbols, 12 privacy manifests,
non-exempt encryption false and zero private/test files were verified. The archive
was development-signed with `get-task-allow`; Xcode's distribution export/upload
succeeded and Apple accepted it. Final exported entitlements were not separately
inspected, so no direct exported `get-task-allow:false` claim is made. Apple accepted
the existing GoogleMobileAds/UMP vendor-dSYM warnings.

Evidence: `build/releases/build29-20260911/`, particularly `qa-status.md`, initial/
focused xcresults, `archive-inspection.json`, upload records and `apple-final-state.json`.
PHP record: `/Users/vlad/Documents/SpeedyTapper-release-artifacts/20260911-mp29.MWy2eo/RELEASE.md`.
Later documentation commits are not new binaries. Outstanding TestFlight QA includes
tutorial controls, pickup stamps, real-account rewards and hosted 2/3/4-device play.
Physical/accessibility/load/legal gates remain open; no App Store production
submission, live-ad activation, new region or paid-plan upgrade occurred.

Rollback references are build 28 and Railway `3041f2bb`/`e866409`; old service code
does not support revision-3 clients or archive ranked acknowledgements. Retain
PHP 025, compatible rewards runtime, all immutable credits/receipts and pending
outbox journals. The retained PHP rollback artifact is build28's `2157ced3…` below,
but old PHP cannot preserve new Multiplayer reward reconciliation: coordinate a
forward correction rather than discard value/evidence or restore an old wallet.
No destructive reset or live rollback was performed.

## Build 28 — retained baseline and rollback evidence

Build **1.02 (28)** is VALID and `APP_STORE_ELIGIBLE`. Direct Apple verification
at **2026-09-11 13:58:51 UTC** confirmed beta review **APPROVED** and both existing
Internal QA / External QA groups **IN_BETA_TESTING**. Automatic notification stays
enabled. The existing external public link, contacts and demo-account settings
were preserved; only this build's en-US What to Test was updated.

| Item | Verified value |
| --- | --- |
| Branch / binary source | `codex/build28-private-rooms` / `3922867341c43c732e894805f829559140f5b5e4` |
| Apple build | `707cd113-dc9c-4410-8547-d13afce6dd1a` |
| Apple upload / expiration | 2026-09-11 13:57:21 UTC / 2026-12-10 13:57:21 UTC |
| Toolchain | Xcode 26.6 (17F113), Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.6.2 |
| Configuration | Staging, iOS 17+, `-O`, whole-module, `STAGING` without `DEBUG`, unchanged owner-split test ads |
| Archive TGZ SHA-256 | `1466af089e7e6d52ca51f25660363595ca8c1bbf51f87f6b8909484328f4642c` |
| 115-file manifest SHA-256 | `0a133114758a2e58813dcf79b827ccb6147e66045d992eb138ed1da15eb63201` |
| App/dSYM UUID | `100EEBB6-E417-3A5A-8BA7-0D03AA201631` |
| App binary SHA-256 | `c28f6001d038feb23080f9fa122e8e13b9078a078ecc92e0a4d56587cb1ac700` |
| App dSYM SHA-256 | `0197c7eb70612736e9e7c6ac15aa68d698ab8cddd73a6caf88307c0e52f7492e` |
| Railway source / deployment | `e866409c6571dd08069db76fabcd07d79016a487` / `3041f2bb-70f4-4a71-8318-039fb8e6aedb`, SUCCESS |
| PHP source | `f84dc9218b58bb937326be931f2ee969abed4282` |
| PHP artifact SHA-256 | `2157ced30057d0b376270378f03ddd8a9d1a4a698cc639993a4dbdb642f3f980` |
| PHP target | `speedytapper.otcsoft.com` / `/home/u966828068/domains/speedytapper.otcsoft.com/public_html` |
| PHP schema / season | Ledger 001–024 and existing season unchanged; no migration or data reset |

PHP was deployed through the owner-confirmed Hostinger prebuilt archive workflow
and verified first. **www.otcsoft.com was not a deployment target and was not
modified.** All 69 PHP source hashes, unchanged private configuration/original
workers and 35 HTTPS boundary checks passed. Live v3/v4/v5 admission is supported.
The source came from an isolated clean PHP worktree; the original PHP checkout
was untouched.

Railway was deployed next, to the existing single Amsterdam instance and volume.
The final app commit contains byte-identical Server/Core source. Native Linux
ARM64 verification passed **40 service and 89 core tests**, plus entrypoint and
readiness checks. Local AMD64 QEMU compilation crashed before its unit gate;
Railway's native AMD64 release build and direct x86_64 runtime checks passed.
PID 1 has UID/GID 10001 and NoNewPrivs; private outbox directories are mode 0700
on the writable persistent volume. Ten live WSS/auth boundaries passed.
Settings, variable fingerprints, regions, billing plan and volume were unchanged;
temporary SSH registration and key files were removed.

The exact final iOS source passed **241 app/UI tests, zero failures/skips, and
89 core tests**. A separate compact SE all-theme room-control test passed, as did
33 focused tests. All eight compact hub/waiting captures were inspected.
Cold compact attempts had an OS UIPasteboard XPC stall and an immediate switch
assertion failure; unchanged test/source passed on the warmed base Simulator.
Those failed attempts and samples remain alongside the passing results.

Four real local socket clients completed 92 seconds: 5,480 snapshots, three
private-code joins, unique rotating colors, safe decoys, no pre-4×4 hearts and one
four-way heart winner. PHP Composer, 56 new v5/111 retained v4 SQLite assertions,
154 v5/112 retained v4 disposable MariaDB assertions passed. These checks are not
physical-device latency or a positive signed-in internet match.

Archive/export/upload succeeded from the clean source. Signature, matching app
symbols, 12 privacy manifests, no private/test files and export task allowance
disabled were verified; non-exempt encryption is false. Apple accepted the existing
GoogleMobileAds/UMP missing-vendor-dSYM warnings; app-owned symbols are retained.

Evidence: `build/releases/build28-20260911/`, including final xcresult,
`apple-final-state.json`, archive/inspection/upload records, `compact-qa.md`,
and `linux-verify.gJC9GU/VERIFICATION.md`.
PHP evidence: `/Users/vlad/Documents/SpeedyTapper-release-artifacts/20260911-arcade-v5.mTFG0j/`.
Later documentation commits are not new binaries.

Rollback references: build 27; Railway `920bd2bf-217e-44b3-ac4c-d3a0f964b812`;
PHP `0a94f5cfe2a36ae89f0d26db1c72bf7cfe4d683c` archive SHA-256
`3e9ad75ff087388038374be64846fe2b3f77ad2ac503379c13f651344cee6d9a`.
The retained PHP rollback is byte-identical to the preceding deployed archive.
A PHP rollback cannot complete v5 attempts; coordinate beta availability first.
A Railway rollback removes code/private discovery; capability gating prevents
silent public creation, but those new features would be unavailable. Retain
schema 024, account data and volume; no rollback was performed.

Real signed-in 2/3/4-device matches, accessibility, 60/120 Hz acceptance, sustained
load/reconnect and public legal/storefront gates remain open. No production App
Store submission, live ads, paid-product activation or paid-plan upgrade occurred.

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
