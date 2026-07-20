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
7. Verify backend deployment supports this API/ruleset/proof/build before archive distribution and remains compatible with the prior live app.
8. Run the physical-device release matrix and document gaps explicitly.

### Advertising configuration gate

| Candidate | Required ad configuration |
| --- | --- |
| Debug/local automation | Real PimPoPom AdMob App ID, Google demo banner/interstitial units, no private test hash |
| Named Staging/TestFlight QA | Demo units by default; build 5 may use the private owner IDFV fingerprint to select production units plus the registered GMA test hash only on that phone |
| Owner Ads QA | Ignored production units plus the owner's ignored hashed GMA test-device identifier; every creative must visibly say **Test mode** |
| Public Release | Ignored production units, `live` mode, no test-device identifier; only after separate owner authorization |

Before any ad-enabled archive, run the configuration validator and inspect the built `Info.plist`. Before public live activation, also verify the current aggregate archive privacy report and App Store privacy answers, UMP consent/privacy-options messages, accepted age treatment, `https://otcsoft.com/app-ads.txt` using the exact personalized AdMob line, AdMob app linkage/readiness, banner/interstitial physical evidence, and server-authoritative Remove Ads behavior. Do not infer or construct the `app-ads.txt` publisher line from memory. No owner test hash belongs in logs, Git, App Store metadata, or a public archive.

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
- The already-uploaded placeholder build's Beta App Review notes must continue to describe its disabled non-granting Ads/StoreKit UI. For any later StoreKit/ad-enabled Staging build, disclose that it uses the live compatibility service and real shared player/ranking/purchase data, optional Game Center authentication, Google demo-labelled ads behind UMP consent, five Sandbox products, server acknowledgement before credit, and in-app deletion. Do not describe the empty Game Center leaderboard as a verified mirror until the Hostinger outbox exists.
- Submission to TestFlight Beta App Review is not approval. Record processing, review, and invitation states independently.

### Internal

- Smoke cold install/update/reinstall, both modes, identity/linking, ranked proof, leaderboard, achievements, themes/pets, audio/haptics, consent/test or approved diagnostic ads, Remove Ads, coin purchase, restore, account deletion, and support URLs.
- Verify production-like server rate limits/alerts without using live ad clicks or uncontrolled real purchases.

### External

- Provide beta description, feedback contact, privacy links, required export information, and App Review access.
- Expand device/OS/locale/region coverage and monitor crashes, hangs, energy, purchase failures, API compatibility, proof review rate, and support incidents.
- Never expose production admin capabilities to general testers.

## App Store submission

Prepare:

- localized name **PimPoPom**, subtitle, description, keywords, category, age rating, support/marketing/privacy URLs;
- real in-app screenshots and previews, including disclosure of paid content where relevant;
- review notes explaining Apple/Google login, nickname confirmation, local play, ranked flow, ads/consent, Remove Ads, Buy Coins, restore, and account deletion;
- a stable reviewer account or approved demo path, a live review backend, and exact navigation to every IAP;
- IAP review screenshots/metadata and any Game Center assets;
- contact information for review and urgent server issues.

Submit only when every configured IAP is functional and visible or clearly explained. Prefer phased release after approval unless an urgent synchronized backend launch requires another accepted plan.

## Production verification

After release:

1. Confirm the exact App Store version/build and seller page.
2. Fresh-install from the store and test launch, consent, sign-in providers, nickname, local Zen, ranked Arcade, finish/rank, shops, a controlled purchase/restore path, Remove Ads, audio/haptics, backgrounding, account deletion entry, and support links.
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
