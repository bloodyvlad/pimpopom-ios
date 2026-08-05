# TestFlight and App Store release

Production submission, live-ad activation, and paid-product activation require
explicit owner authorization. A TestFlight approval is not an App Store release.

## Current beta and rollback

### PimPoPom 1.02 (20) — current TestFlight

| Record | Value |
| --- | --- |
| Archive source | `69fe7422719dd4953e90354a2ae3f3c976995db7` |
| Release-record commit | `d182ecf62d8bd360b64b97d8c1080d3389a2c239` |
| Toolchain | Xcode 26.6 (`17F113`), Swift 6.3.3, iPhoneOS SDK 26.5, macOS 26.5.2 |
| Identity | `com.otcsoftware.pimpopom`, team `APX2925X66`, `1.02 (20)` |
| Capabilities | Sign in with Apple, Game Center, `iCloud.com.otcsoftware.pimpopom` |
| Archive manifest SHA-256 | `8ed8bd8140547a858befeadc0bfa03a9c1dc1207c69fdb43b6f2677843e36516` |
| App Store Connect ID | `a98b6bcf-1560-4c17-84cb-dffef47c0778` |
| App Store Connect state | VALID; Beta Review APPROVED; Internal/External QA testing |

The reproducible archive/export/DerivedData were removed after acceptance. Retained
app dSYM UUID `AC66885A-C79E-375E-A299-D8472AE8D7C1` is stored at
`/Users/vlad/Documents/PimPoPom-symbols/1.02-20/PimPoPom-1.02-20-69fe742-AC66885A-C79E-375E-A299-D8472AE8D7C1.dSYM.zip`, SHA-256
`0fb5c5ccdab44c7f1b9466cff8b5280edaa870f1be4eef7fe569f19ac4cf5510`.

The exact archive source was clean, and signature/absence-of-secret checks passed.
The retained local archive used Apple Development signing, including
`get-task-allow`; App Store upload re-signed it for distribution. Apple accepted
the known missing vendor-framework dSYM warnings for Google Mobile Ads UUID
`90EDFF16-0A30-3944-A8D1-DC4FB9D1E710` and UMP UUID
`3C3DB97D-600E-3898-906E-3AE471432865`; the app dSYM is retained.

Focused presentation/cosmetics checks passed, but the owner explicitly skipped the
final spacing rerun and full `Scripts/check.sh`. Real 2/3/4-device Multiplayer and
the physical gates in `TESTING.md` remain open. Build 20 is not production.

### PimPoPom 1.02 (19) — beta rollback

| Record | Value |
| --- | --- |
| Archive source | `95d9cde7f1b594208461b450b9023a5cec3fabc0` |
| App Store Connect ID | `81190b4a-a909-46c5-82b1-74055c47dc93` |
| Archive manifest SHA-256 | `16d93d1e1931553626d86f7965524f745e6d14601903480ec419f819f89d50d2` |
| App dSYM UUID | `7A027C4C-FFE4-33B5-9695-C7033895D8F7` |
| dSYM SHA-256 | `0b2b51de5b5cf57b08df12ac0e321cc9809921e8b38ec074dd2a04150ae70b3d` |
| Verification | Full `Scripts/check.sh`; 52 core and 224 native paths passed |

Build 19 remains assigned as rollback. Its waiting room is pet-free and therefore
does not represent current build-20 presentation.

Older beta records are retained in Git/App Store Connect history, not repeated in
the current document.

## Candidate identity record

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
6. Complete the named physical matrix. Multiplayer needs real 2/3/4-device matches;
   FAST changes need the latency/loss/reorder acceptance plan.

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
