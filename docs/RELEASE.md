# TestFlight and App Store release

Production submission, live-ad activation, and paid-product activation require
explicit owner authorization. A TestFlight approval is not an App Store release.

## Current beta and rollback

### PimPoPom 1.02 (21) — current TestFlight

| Record | Value |
| --- | --- |
| Archive source | `66ffd0b3687d198682e85aa4bfcf40ac4dcbb88d` |
| Toolchain | Xcode 26.6 (`17F113`), Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2 |
| Identity | `com.otcsoftware.pimpopom`, team `APX2925X66`, `1.02 (21)` |
| Capabilities | Sign in with Apple, Game Center, `iCloud.com.otcsoftware.pimpopom` |
| Archive manifest SHA-256 | `164038c574d012e4fc636e3e311a89504e1169375f08b5d3329b44bf8d483564` |
| App Store Connect ID | `1d82306d-5fe7-42a2-a89d-cd779e9e0402` |
| App Store Connect state | VALID; Beta Review APPROVED; Internal/External QA testing |

Retained app dSYM UUID `B2C6A380-0E9D-3506-89D3-F434A8DBA9A9` is stored at
`/Users/vlad/Documents/PimPoPom-symbols/1.02-21/PimPoPom-1.02-21-66ffd0b-B2C6A380-0E9D-3506-89D3-F434A8DBA9A9.dSYM.zip`, SHA-256
`4be20ad821a3f92df2cd05fa11def9f1d53b288d73b29cdd373207dd58220a0c`.

The exact archive source was clean, and signature/absence-of-secret checks passed.
The retained local archive used Apple Development signing, including
`get-task-allow`; App Store upload re-signed it for distribution. Apple accepted
the known missing vendor-framework dSYM warnings for Google Mobile Ads UUID
`EB9A4FC5-240A-3B25-8A64-0502A26A5426` and UMP UUID
`A7A40082-1EE7-31CA-AA1B-93BABE913CAB`; the app dSYM is retained.

The clean release commit passed 69 core and 272 native tests, including the shared
four-theme fly-outs and Pixel back-button edge tap. Build 21 contains FAST local
prediction, sealed input frontiers, measured policy gating, reliable evidence and
resolution recovery, the exact five-point HUD-to-board spacer, and unchanged PHP v1
transcripts. Real 2/3/4-device and 60/120 Hz FAST acceptance remains open. Build 21
is TestFlight beta software, not a production App Store release.

### PimPoPom 1.02 (20) — beta rollback

| Record | Value |
| --- | --- |
| Archive source | `69fe7422719dd4953e90354a2ae3f3c976995db7` |
| Release record | `d182ecf62d8bd360b64b97d8c1080d3389a2c239` |
| App Store Connect ID | `a98b6bcf-1560-4c17-84cb-dffef47c0778` |
| State | VALID; Beta Review APPROVED; retained in both QA groups |

Older beta records and detailed evidence remain in Git/App Store Connect history.

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
3. Verify the deployed backend accepts the candidate's Arcade and Multiplayer
   build/ruleset/proof tuples and still supports the rollback client.
4. Inspect archive Info, entitlements, signature, aggregate privacy report, symbols,
   asset catalog, and absence of `.p8`, `.storekit`, ignored config, debug fixtures,
   and credentials.
5. Confirm public Privacy/Support/account-deletion/Terms URLs, seller/rights, export,
   age, privacy, IAP, Game Center, ads/UMP, and reviewer metadata.
6. A TestFlight QA candidate may upload with physical gates explicitly open. Complete
   real 2/3/4-device and latency/loss/reorder acceptance before FAST acceptance or
   production submission.

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
