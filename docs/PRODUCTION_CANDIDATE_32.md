# Build32 Apple age integration

Owner-authorized scope on 2026-09-12: automatic Apple age ranges, read-only age for
Apple-shared/parentally controlled accounts, existing 13+ access/ad protections,
TestFlight upload and submission of the same binary for public App Store review.
The already-implemented `npa=1` request flag remains. Three-game cadence, gameplay,
paid-value handling and backend contracts are unchanged. Build31 (`16d6321`) and
its signed local artifacts remain retained separately.

## Age and fallback behavior

- iOS26.4+ checks `requiredRegulatoryFeatures`, then requests13/16/18 age gates.
  iOS26.2/26.3 uses `isEligibleForAgeFeatures` for the regional required gate.
- Apple ranges are inclusive and may override requested thresholds. Lower bound
  below13/unknown cannot establish access. Lower13–15 uses child/under-consent
  protection,16–17 teen,18+ adult; broad13–17 stays in the stricter ad lane.
- Shared values are read-only, with actual bounds shown and a refresh action.
  Corrections belong in Apple Account settings; no birthday is collected.
- iOS17/18 retains manual13+ self-declaration. iOS26.0/26.1 requests Apple age but
  has no regulatory-query API; declined/unavailable optional sharing uses the
  legacy manual gate only if no Apple range has ever been shared. This does not
  prove absence of parental controls. No forced iOS-upgrade gate is introduced.
- On newer systems, optional declined sharing permits manual fallback only after
  a successful non-required regional determination and no remembered Apple lock.
  Errors/required declines stay retryable and blocked; no saved adult override.
- Every valid shared response establishes the persistent Apple lock, even if its
  active authorization is stale. Startup/account/background refreshes are serialized
  after existing UMP presentation. Only current responses may reopen eligibility.
  A background recheck preserves existing navigation under a blocked surface and
  the existing gameplay background behavior; initial unresolved launch creates no Root.
- No PermissionKit/significant-update approval or AppTransaction consent state is
  introduced for this first public release. Future significant changes must be
  reviewed against Apple's then-applicable notification/parental-consent requirements.
  This feature is not a claim of complete regional legal compliance or backend
  RESCIND_CONSENT enforcement.

## Verification and release boundary

Final focused check: **64 unit tests and 2 Apple age UI tests passed**, zero
failures/skips. The preceding run also passed62 unit and5 age UI checks, including
the retained manual fallback/correction flow. A true Release compile passed before
the final callback integration; the signed archive will compile the final source.
The independent reviewer found no remaining blocking age/consent defect. Initial
Swift6 adapter/test compile failures are retained separately, not counted as passes.

The owner overrides the broad repository gate: run only age/consent tests and
necessary compile/archive/export checks. No new gameplay/core/tutorial/Multiplayer
suite, and no physical/manual QA before submission. Historical build31 evidence
is not presented as a new build32 run. Focused results and any initial failures,
exact source SHA, signed-entitlement checks, IPA/archive hashes and Apple state
are retained under `~/.local/share/pimpopom-releases/20260912-production32`.

Checked-in Release remains disabled. The authorized archive uses verified live
AdMob IDs and blank active/owner QA fields. Export inspection verifies distribution
signing, Declared Age Range entitlement in app and provisioning, matching dSYM,
privacy inventory, legal URLs and excluded capture/test/private content. App Store
metadata and privacy-label publication are coordinated separately. Public review
submission is distinct from Apple approval and public availability.

Primary references: [Apple age assurance](https://developer.apple.com/support/age-assurance/),
[Declared Age Range](https://developer.apple.com/documentation/declaredagerange/agerangeservice),
[entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.declared-age-range).
API names and availability were checked against installed Xcode26.6/iOS26.5 Swift interfaces.
