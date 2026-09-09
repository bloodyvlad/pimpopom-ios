# TestFlight and App Store release

Production submission, live-ad activation, and paid-product activation require
explicit owner authorization. A TestFlight approval is not an App Store release.

## Current candidate, beta, and rollback

| Item | Current truth |
| --- | --- |
| Configured version | `1.02 (24)`; unchanged pending a future authorized release |
| Last direct App Store Connect check | 2026-09-08: build 24 VALID, uploaded 2026-08-22 |
| Groups / external state | Internal QA and External QA; `READY_FOR_BETA_SUBMISSION`, not proof of external testability |
| Uploaded binary | Historical GameKit/v1 beta, not today's v2 source |
| Local candidate | New native socket/shared-core/Vapor v2 plus separate PHP bridge; not deployed/uploaded |
| Rollback beta reference | Build 20, source `69fe7422719dd4953e90354a2ae3f3c976995db7`; current installability not reverified |
| Authorized work | Local code/research only; no host purchase, deployment or new TestFlight upload |
| Production App Store | No production release established by this task |

Hosting choice, authenticated WSS/PHP integration, exact source gates and physical
2/3/4-device/60/120 Hz acceptance remain open. Keep archive/dSYM/source identity
separate from the build number: no exact v2 commit is associated with the uploaded
build 24. Direct external-state evidence is summarized in CURRENT_VERSION.md.

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
   production submission. Today's local-code task does not authorize any upload.

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
