# Build 33 age onboarding correction

The owner withdrew build 32 from public App Store review after a physical iPhone
running iOS 27 Beta 6 showed an immediate generic age-check failure, followed by
Apple's Age-Appropriate Experiences setup when retried. ASC independently reported
`DEVELOPER_REJECTED`. The screenshots do not identify the underlying SDK error or
establish that TestFlight caused it; no production-only success is assumed.

Code review found two app-side problems: the initial request could run before a
foreground, attached presentation window existed, with no automatic retry on the
first active transition; and every modern Apple sharing error blocked startup,
even when regional sharing had already been determined to be optional.

## Requested behavior

- On iOS26.2+, read `AgeRangeService.shared.isEligibleForAgeFeatures`. Only
  `true` triggers `requestAgeRange`; `false` permits the default unspecified ad policy
  without requesting Apple sharing. Older systems use the same unknown-age
  fallback. Previously known child restrictions remain without an optional
  re-prompt. Open directly to the main menu after any required regional check. No manual age
  selector and no optional Apple sharing/setup prompt, including at purchase.
- Keep actual age absent when it is not supplied. Ads use unspecified age
  treatment and regular UMP consent handling for unknown age, alongside General content,
  non-personalization, disabled first-party ID, UMP permission and authoritative
  ad-free/account state. No invented age or new backend field is stored.
- Keep required-region checks and known Apple age/parent restrictions. A failed
  regulatory query does not establish optional status. A known under-13 result
  cannot become an adult override.
- Request required system UI only after an active, attached presenter is ready.
  Diagnostics record stage/domain/code without age or identity data. No
  unclassified failure is described as a connection problem.
- Use ordinary StoreKit purchases, with no extra age-sharing hook or custom
  parental-approval flow. No new AdMob dashboard settings are changed.
- Remove the manual age editor and all onboarding Settings/legal links. Main-menu
  Settings retains Support & Legal and applicable privacy choices. Existing Apple
  ranges are shown read-only there. Add the existing PimPoPom wordmark to the
  required-check screen.
- Restore the original `person.3.fill` icon on the Multiplayer button while
  keeping its removed subtitle absent. Gameplay is unchanged.

Manual selection was an app implementation choice for its earlier differentiated
age policy, not a universal Apple requirement. App content ratings do not prove
an individual player's age. Ad treatment flags facilitate specific protections;
this change makes no claim of automatic worldwide legal compliance.

## Verification and delivery

Only focused age/consent checks, required compile/archive/export checks and diff
checks are in scope. Do not run gameplay/core/tutorial/match suites. Simulator
fixtures are not evidence of Apple's live iOS 27 account/setup behavior. A new
TestFlight build will enable the owner's physical-device check; public review
remains withdrawn until the owner resumes it.

## Primary references

- [Apple age assurance Q&A](https://developer.apple.com/support/age-assurance/):
  checks are required for users in applicable regions, not only purchasers.
- [Requesting age ranges](https://developer.apple.com/documentation/declaredagerange/requesting-people-share-their-age-range-with-your-app):
  applicability and sharing are separate API operations.
- [Apple Age Range privacy](https://www.apple.com/legal/privacy/data/en/age-range-for-apps/):
  Apple manages setup, sharing and Screen Time authentication. The app receives
  neither the birthday nor a passcode.
- [Sandbox testing](https://developer.apple.com/documentation/storekit/testing-age-assurance-in-sandbox):
  Apple provides simulated age/regional scenarios; these do not establish a
  blanket TestFlight limitation or guarantee production success.
- [App Review privacy requirements](https://developer.apple.com/app-store/review/guidelines/#privacy):
  privacy policy must be easily accessible in-app; first-launch display of every
  legal document is not required by this guideline.

## Focused validation result

The combined Simulator run passed **67 tests: 29 Apple age unit tests, 31
advertising-consent/account unit tests and 7 launch/Settings UI tests** with zero
failures or skips on PimPoPom Production QA / iOS26.5. Captures confirm the menu
with a test banner and Multiplayer icon, the branded required-check screen, and
legal links in main-menu Settings. Gameplay suites were not run. Strict formatting
and `git diff --check` pass. StoreKit, RootView and gameplay/server source are
unchanged from build32. Three inherited warnings in compiled test files remain;
those unrelated Game Center and Purchase test methods were not executed.

The xcresult and signed release evidence are held outside the repository under
`~/.local/share/pimpopom-releases/20260912-onboarding33/`. Simulator fixtures do not
establish live Apple behavior on the owner's iOS27 device. TestFlight status must
be verified in App Store Connect after upload; it is not implied by this source.
