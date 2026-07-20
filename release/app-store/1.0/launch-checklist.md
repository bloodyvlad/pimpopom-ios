# PimPoPom smooth App Store launch checklist

This is the working owner/engineering checklist for the first production release. A checked technical beta is not automatically a production-ready App Store binary.

## 0. Submission blockers

- [ ] Obtain and retain public-release rights evidence for every pet source/master/runtime sprite in `assets/pets/SOURCES.md`.
- [ ] Obtain and retain public-release rights evidence for the Disco texture sources in `assets/themes/SOURCES.md`.
- [ ] Complete PimPoPom trademark/brand clearance and confirm the enrolled seller/rightsholder name.
- [ ] Add Sign in with Apple or document and validate a genuine App Review Guideline 4.8 exception. Build 6 exposes Google Sign-In for the primary profile but no Sign in with Apple path.
- [ ] Add the public-leaderboard safety path appropriate to player nicknames: filtering, reporting, blocking where applicable, support escalation, and a documented moderation policy.
- [ ] Publish HTTPS Privacy Policy, Support, Terms, and account-deletion help pages controlled by the seller.
- [ ] Create a true public Release archive. Build 6 intentionally contains owner-only production-unit QA and demo-unit routing for other testers; that is not a public monetization policy and must not ship unchanged.
- [ ] Verify StoreKit credit, refund, reversal, revocation, debt, Family Sharing, and account deletion end to end in Sandbox on a physical iPhone.
- [ ] Configure and verify App Store Server Notifications V2 for both Sandbox and Production. One environment-aware backend endpoint may serve both URLs.
- [ ] Produce the final archive privacy report and answer App Privacy for the app plus Google Mobile Ads, UMP, Google Sign-In, and every other included SDK. Do not guess from runtime intent alone.

## 1. Product and legal setup

- [ ] Confirm app name `PimPoPom`, bundle ID `com.otcsoftware.pimpopom`, Apple app ID `6792328590`, SKU, and seller display name.
- [ ] Resolve the version identity deliberately: the App Store version record began at 1.0 while TestFlight currently uses marketing version 1.01.
- [ ] Keep the app price Free and confirm United States/Canada availability for version 1.0 and all five in-app purchases.
- [ ] Confirm Paid Apps Agreement, tax, and banking remain active.
- [ ] Confirm copyright as `2026 [rights-owning entity]` only after seller ownership is settled.
- [ ] Complete Content Rights honestly. Third-party fonts, ad content, and licensed/generated art must all have retained rights evidence.
- [ ] Complete the current age-rating questionnaire. Declare advertising. Treat the ranked leaderboard as a possible skill-based “Contest” even without prizes; use the least frequency that truthfully describes actual play. Do not choose Kids Category merely to broaden reach.
- [ ] Keep Jersey 10’s SIL OFL 1.1 licence and font provenance with the release records.

## 2. Storefront metadata and media

- [ ] Review and approve `metadata/en-US.md`.
- [ ] Publish the Support and Privacy Policy URLs before submission; add a Marketing URL only if a stable page exists.
- [ ] Upload the six numbered 1260×2736 PNGs from `screenshots/6.9-inch/` in order. Verify every capture still matches the submitted build.
- [ ] Replace any screenshot whose test fixture, price, balance, player name, or feature no longer matches production behavior.
- [ ] Keep real player data, email addresses, device identifiers, ad test hashes, and credentials out of all media and metadata.
- [ ] Use only screenshots showing the app in use. Do not use the fake `Test ad` UI captures in storefront marketing.
- [ ] Decide whether to record an App Preview. It is optional; if included, follow `video-shot-list.md` and Apple’s 15–30 second capture rules.
- [ ] Use `banners/` for website/social/press. Do not search for a generic App Store banner field—there is none.
- [ ] If Apple requests featuring artwork, produce the requested sizes from the clean campaign sources instead of assuming the existing banners match that brief.

## 3. App Store Connect configuration

- [ ] Confirm App Privacy answers from the actual uploaded archive and current SDK privacy manifests/signatures.
- [ ] Confirm `ITSAppUsesNonExemptEncryption = NO` if the binary still relies only on exempt Apple-system transport/security and contains no custom/non-exempt cryptography. Upload documentation only if the final binary changes that conclusion.
- [ ] Verify all five IAP records: localized display names/descriptions, US/Canada pricing, tax category, availability, review screenshots, and Ready to Submit state.
- [ ] Give App Review a clear explanation of the persistent account-bound ad-free benefit included with consumable coin packs; confirm Apple accepts this product treatment before launch.
- [ ] Submit the first IAP products with the first app version as Apple requires.
- [ ] Verify `com.otcsoftware.pimpopom.removeads.lifetime` is non-consumable, restorable, and Family Sharing is enabled; coin packs remain consumable.
- [ ] Confirm the Sandbox and Production notification URLs respond correctly and route by Apple-signed environment.
- [ ] Confirm the permanent Game Center `Arcade` leaderboard is attached only if its component and server-fed mirror are ready for this release. Optional local authentication must never block play.
- [ ] If submitting the first Game Center component, include it with the same app version.
- [ ] Select manual release for version 1.0 so approval does not publish unexpectedly.

## 4. Release archive

- [ ] Build with Xcode/iOS 26 SDK or later, using Release configuration and the final production signing identity/profile.
- [ ] Confirm visible name `PimPoPom`, version/build, icon sets, bundle ID, entitlements, URL schemes, privacy manifest aggregation, and no Debug/TestFlight fixture flags.
- [ ] Confirm no `.p8`, OAuth secret, review password, owner device hash, private IDFV fingerprint, local config, or test backend material is embedded in the archive or dSYM.
- [ ] Remove demo-ad routing and owner fingerprint/test-device logic from the public binary. Use approved production units for all eligible public users—or keep ads globally disabled until live activation is explicitly authorized.
- [ ] Validate the archive before upload and review Organizer warnings.
- [ ] Upload the exact reviewed commit, record commit SHA/build/archive checksum, and retain the archive and dSYM.
- [ ] Wait for processing, then inspect App Store Connect’s generated privacy report and export-compliance status before selecting the build.

## 5. Physical-device acceptance

- [ ] iPhone SE 2022 / 60 Hz: fixed menu, compact Remove Ads control, 320×50 banners, Arcade/Zen geometry, purchase sheets, account deletion.
- [ ] iPhone 13 mini / 60 Hz: tall-menu Remove Ads path, safe areas, banners, shops, keyboard, profile, leaderboards.
- [ ] iPhone 13 Pro / 120 Hz: tap timing, animation pacing, audio/haptics, SpriteKit rendering, background/foreground recovery.
- [ ] Fresh install, upgrade from latest TestFlight, reinstall, account switch, signed-out play, Google sign-in, Game Center unavailable, and poor/no network.
- [ ] Arcade ranked start/finish, leaderboard save/read, anti-cheat withholding state, Zen isolation, achievements, coins, pets, themes, sound/music/glyph persistence.
- [ ] StoreKit Sandbox: each coin pack, Remove Ads, pending/cancelled/unverified states, Restore Purchases, unfinished transaction recovery, refund/reversal/revocation, and family entitlement behavior.
- [ ] Ads: UMP first launch, Privacy Choices, consent changes, no-fill/failure, fixed gameplay banner below Speed Bar, interstitial after every 3 eligible completed results, backgrounding, and immediate ad-free teardown.
- [ ] Verify that ad-free accounts construct no banner container, placeholder, spacer, or ad note outside the explicitly documented mid-run invisible geometry preservation.
- [ ] VoiceOver labels, Dynamic Type where supported, contrast, Reduce Motion, mute switch expectations, and one-handed reachability.
- [ ] Capture final screenshots only after this pass; compare against the proposed storefront frames.

## 6. App Review package

- [ ] Provide a working reviewer demo account if ranked play or account-bound purchase credit cannot be fully reviewed anonymously. Put credentials only in App Store Connect Review Notes.
- [ ] State clearly that sign-in is optional for basic Arcade/Zen evaluation.
- [ ] Give exact paths for StoreKit, Restore Purchases, Privacy Choices, and Delete Account.
- [ ] Explain banner placement and the after-3-completions interstitial cadence.
- [ ] Explain that TestFlight/Sandbox purchases do not charge real money.
- [ ] Add a reachable review contact and monitor email/phone during review.
- [ ] Attach any Apple-requested IAP or account-deletion explanation promptly; do not change server behavior underneath an in-review build without reassessment.

## 7. Release and post-launch

- [ ] After approval, choose the manual release window and confirm backend, notification processing, support coverage, and monitoring are healthy.
- [ ] Verify the live product page, screenshots, privacy link, prices, IAP availability, Game Center state, and download on a clean device.
- [ ] Monitor crashes, sign-in failures, ranked-run errors, StoreKit acknowledgement latency, notification failures, refunds/debt, ad fill/errors, and support mail.
- [ ] Keep a rollback/kill-switch plan for ads, ranked submission, purchases, and server incompatibility.
- [ ] Triage reviews and support reports without exposing player payment evidence or personal data.
- [ ] Prepare the first maintenance update only from a new reviewed build; do not repurpose the approved binary’s server contract silently.

## Official references

- [App Store screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [App Preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Product page guidance](https://developer.apple.com/app-store/product-page/)
- [App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [In-App Purchase configuration](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/)
- [App Store Server Notifications URLs](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/enter-server-urls-for-app-store-server-notifications)
- [Game Center submissions](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-game-center-components)
- [Export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation)
- [Third-party SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)
