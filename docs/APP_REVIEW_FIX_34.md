# Build 34: age assurance and adult tracking consent

Owner-authorized correction for the rejection of 1.02 (33), submission
`c75ba21e-c5f2-431b-ac51-e450e088ec9b`, under 5.1.2(i) and 2.3.6.
Candidate based on clean build-33 source `2077df82a1ae0a71998edfa0977f61b680aa18cf`.
Archive, upload and review status require separate receipts; configuration alone
is not release evidence.

## Behavior

1. Check Apple's regional eligibility at launch. A required range uses Apple's
   13/16/18 thresholds; an unavailable or declined required range cannot be
   bypassed manually. Apple-supplied restrictions remain read-only.
2. Optional/legacy eligibility with no existing choice shows a one-time neutral
   Under 13 / 13–15 / 16–17 / 18+ / Skip question. No birthday is collected.
   Skip is remembered independently of an age band. Under 13 blocks access.
3. Run the Google UMP refresh and applicable consent form. Only an adult whose
   applicable regulatory choices permit personalization is eligible for the
   native ATT request. Native ATT is requested after UMP finishes presenting.
   No separate AdMob IDFA explainer is configured. UMP supports this native ATT
   integration; keeping it app-controlled prevents ATT requests for teens/Skip.
4. The ad SDK and inventory wait for the completed consent flow and authoritative
   ad entitlement. Adults may enable personalization only with ATT authorization
   and applicable Google permission. Google also enforces its remaining TCF/GPP
   signals. All other requests use NPA, publisher personalization off and publisher
   first-party ID off. 13–15 uses UMP underage/GMA child; 16–17 uses GMA teen.
   Unknown uses unspecified treatment and does not imply adulthood.
5. Existing creatives are discarded on privacy-choice changes or observed ATT
   revocation. A denied/restricted ATT result does not block local play.
6. Login/logout/account switching preserve stored age and consent answers. Google
   still performs its required launch refresh. Production never invokes UMP reset.
   Legal documents and required privacy choices stay in main-menu Settings.

Scope excludes gameplay, ad cadence (three completed games), backend deployment,
StoreKit behavior, storefront copy/media and territories. Standard StoreKit and
Apple parental purchase controls remain unchanged. This app does not claim
custom Parental Controls.

## External changes verified 19 September 2026

- App Store Connect app 6792328590: Device ID marked Used to Track You and
  published. Other existing data types/purposes retained. Google's bundled
  privacy manifest declares linked/tracking Device ID; app-owned first-party
  gameplay/account manifests remain nontracking. Aggregate privacy was checked.
- Age Assurance Yes, Parental Controls No verified in App Information.
- AdMob: existing European and US-state messages active; no IDFA explainer.
  No AdMob console settings changed for this correction.
- Published legal plugin 1.0.2 to the existing `otcsoft.com` WordPress installation
  29642768, `wp-content/plugins/otc-pimpopom-legal` (not the API website).
  Legal source `cf43981330517fd1104b86bb360b268e0522ac32`, clean branch
  `codex/pimpopom-att-legal`. Archive SHA-256
  `0ffe61cd989cd601b888117d41e8dd9c2a5c14c35ac6f30dcaae25148ce15b95`.
  All seven public assets returned HTTP 200 and matched committed bytes;
  other installed plugin records were unchanged. Privacy/support copy explains
  adult ATT and the one-time fallback; all four existing legal URLs are retained.
  Rollback is plugin 1.0.1, source `6a531adbd740079f25093fe441c0f33a76bd0f1e`,
  archive SHA-256 `81ce1c1470779e8a0a1ed64aeae885c50c790d67eb3807b617d6ee315bfe02cd`.
  The unrelated dirty original legal checkout was preserved.

## Verification scope

Only launch, age, consent, privacy settings and build/static checks are authorized.
The full Scripts/check.sh gate would run gameplay tests and is intentionally not
run. Focused policy tests cover Apple eligibility and sticky restrictions,
manual fallback/Skip persistence, account-switch preservation, cancellation,
consent failures, entitlement gating, conditional personalization and revocation.

UI checks use iPhone 17 and iPad Air 11-inch (M3) simulators, iOS 26.5 (23F77).
iPad runs the existing iPhone compatibility app; device-family scope is unchanged.
Real Google UMP + native ATT checks use DEBUG-only fake ad inventory and fake
backend/StoreKit. They exercise adult acceptance, ATT refusal, Google refusal,
13–15, 16–17 and Skip, plus relaunch persistence. No live ads are clicked.
Apple regional/parental scenarios are injected only in DEBUG and separately
covered by controller tests. These are not real Apple Account/physical-device
age assurances. Test-only permission resets do not ship in Release.

Private evidence directory:
`~/.local/share/pimpopom-releases/20260919-att34/`.
Archive/export inspection must confirm exact clean source, Release optimization,
ATT purpose/framework, production AdMob IDs, no QA IDs/flags, distribution
signature/entitlements, matching dSYM UUID, legal URLs and the 12 SDK/app privacy
manifests. Physical iPhone ATT/age/ads verification remains unperformed; the owner
authorized submission following the focused simulator checks without gameplay QA.

## Sources

- [Google UMP and GDPR / native ATT](https://developers.google.com/admob/ios/privacy/gdpr)
- [Google IDFA / ATT](https://developers.google.com/admob/ios/privacy/idfa)
- [Google advertising modes](https://developers.google.com/admob/ios/privacy/ad-serving-modes)
- [Apple tracking permission](https://developer.apple.com/app-store/user-privacy-and-data-use/)
- [Apple age assurance sandbox](https://developer.apple.com/documentation/storekit/testing-age-assurance-in-sandbox)

## Focused results

- Initial selected unit run: 73 passed; the unknown-age failure test needed the
  newly required explicit Skip. That corrected test and both new conditional-ad
  inventory/revocation tests passed in the targeted follow-up.
- iPhone launch/age UI cases passed; final real-consent run passed all three tests
  (six adult/teen/Skip/refusal scenarios plus persistence), result bundle
  `test_sim_2026-09-19T18-57-35-961Z_pid69786_201e2e96.xcresult`.
- iPad initial six cases passed, including ATT refusal and all four no-ATT cases.
  Parental read-only foreground test passed after replacing an iPad-incompatible
  exact background-state assertion. Final adult UMP→ATT→menu→relaunch test passed,
  `test_sim_2026-09-19T19-00-36-280Z_pid69786_fab5025f.xcresult`.
- Failed automation attempts are retained. The final harness waits for the
  SpringBoard answer to dismiss and retries only the same visible answer if the
  system ignored an animation-time tap. UMP's cached hidden WebView is not used
  as evidence of a visible prompt; relaunch checks actual menu/Settings access.
- Strict Swift formatting on changed files, project generation/Debug compilation,
  ad-configuration checks, plist lint and `git diff --check` passed.
