# Build 35: shop and account review fixes

Prepared September 25, 2026, on remote main merge `ec46335` (PR #2, age/ATT).
Version 1.02 (35). Uploaded from exact clean commit `8bcf9b32c6fdb192222a615795e8fc666fa26aab`. See [release evidence](RELEASE.md).

## Changes

- Signed-out Multiplayer and every shop sign-in action open My Profile; Multiplayer retains its group icon and adds SIGN IN TO PLAY.
- Pets and Themes use explicit Buy for N coins actions. Themes have separate buttons below tiles and no routine explanation paragraph.
- Coin Store uses the existing pixel coin, removes Apple-verified wording and the sign-in card, and enables Sign in to buy actions for guests.
- Log out is red. Primary sign-in creates a missing profile automatically. The client confirms the server-generated nickname through the existing authoritative profile-save endpoint before publishing the authenticated session; the name is prefilled and can be changed later.
- Profile and Achievements show available content while refreshing instead of blocking the whole screen.
- Age, ATT, consent persistence, ad configuration/cadence, gameplay, economy, backend and storefront media/copy remain unchanged.

## Verification

- Focused simulator checks: four passed, zero failed, on iPad Air 11-inch M3 / iOS 26.5. Two cover guest/signed-in shop and Profile navigation/presentation; two cover generated-name confirmation and avoiding redundant saves.
- Guest sign-in routing also passed on iPhone 17. New shop/Profile screenshots were inspected on iPhone; final iPad launch/menu was inspected directly. XCTest app screenshots on the iPad were cropped by the capture path, so those captures are not full-screen visual evidence.
- Debug simulator build/run succeeded. Strict formatting and diff whitespace checks passed.
- No gameplay tests or transactions were run. The owner explicitly requested only a quick visual check; the full Scripts/check.sh gameplay suite was omitted. No physical-device validation is claimed.
- Private local evidence: ~/.local/share/pimpopom-releases/20260925-review35/FinalShopChecks.xcresult and captures.

## Loading delay

Read-only production timings: session 0.331 seconds, first achievements request 11.390 seconds, repeated achievements request 0.274 seconds. This confirms an intermittent server-side response delay, not a proven PHP root cause. No backend deployment or database changes were made. Removing the client blocking indicator improves presentation but does not establish a backend latency fix.

## Delivery

Direct Apple verification on September 25: build 35 is VALID / APP_STORE_ELIGIBLE, beta review APPROVED, and both existing QA groups are IN_BETA_TESTING. Public submission `2d700cdb-2d54-4f0a-b431-ff3d3b84ea94` has 13 items and is WAITING_FOR_REVIEW, with automatic release after approval. The old rejected submission was completed by removing its review items, then the same companion versions were added to the new submission; no product definitions or prices changed. No browser state is claimed as evidence; this readback is from Apple's official API.

Original iOS checkout's unrelated docs/API_CONTRACT.md changes and untracked AppStoreConnect/ and workspace settings were preserved. PHP and previous age worktrees were untouched.
