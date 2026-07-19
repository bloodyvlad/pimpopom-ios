# Monetization and privacy design

Status: product, price, entitlement-source, paid-value, refund, and initial US/Canada rules are accepted in P-031. The five App Store products and US/Canada availability are configured, the source-aware PHP backend is deployed, and P-033 accepts the test-safe AdMob/UMP client architecture. App Store review metadata/screenshots, the age questionnaire, UMP dashboard messages, `app-ads.txt`, archive privacy review, and real Sandbox/TestFlight purchase/ad validation remain release gates.

## Product principles

- Gameplay remains available without login for local practice, but durable progression and coin purchases require a server profile.
- Digital functionality and in-game currency use Apple In-App Purchase in the iOS app.
- The app never trusts local balance, entitlement, price, ownership, ad state, or purchase completion.
- Declining tracking or optional ad consent cannot block core play or paid purchases.
- Avoid manipulative pricing, accidental ad taps, forced ads in the reaction loop, pay-to-win scoring, expiring purchased coins, or dark patterns around restore/refund.

## Required entry points

### Remove Ads

- Location: lower-right safe layout of the Main Menu.
- Minimum interactive target: 44×44 points, with localized text and VoiceOver description.
- States: available with localized StoreKit price, purchasing, pending, owned, unavailable, failed, and restored.
- A visible **Restore Purchases** action belongs in the purchase sheet and Settings/Profile support surface.
- Product: `com.otcsoftware.pimpopom.removeads.lifetime`, one $1.99 non-consumable. It is the only Apple-restorable and Family-Shareable product; the current backend requires a signed-in PimPoPom profile for reconciliation.

### Buy Coins

- Locations: Theme Shop and Pet Shop.
- Both open one shared coin-store sheet; no duplicated product logic.
- Show localized StoreKit product display/price and the server-confirmed resulting balance.
- If an item is unaffordable, its action may route to the same sheet without preselecting a misleading pack.
- Coin packs require an authenticated PimPoPom account so the server can bind the credit. Do not sell anonymous coins that cannot be recovered.

## Ad host and lifecycle

The requested host sits at the absolute bottom of gameplay, below the **Speed Bar** (the requested “speed rating bar”) and above the bottom safe-area inset. It is distinct from the target response/deadline bar inside the color field. The bottom order is pet if visible, Speed Bar, separator, reserved ad host, safe-area inset.

Requirements:

- Reserve the maximum accepted banner height before gameplay starts.
- Center an official 320×50 banner within the safe available width. Google Mobile Ads 13's supported large anchored-adaptive replacement can be 50–150 points tall, so it cannot satisfy this accepted strict 50-point host without clipping. Revisit the reservation before adopting that format.
- Add visual separation; never place gameplay controls inside or behind the ad host.
- Ad fill, refresh, no-fill, consent, network failure, rotation, and Remove Ads cannot change the board frame during an active run.
- Hit-test instrumentation proves a board tap cannot reach the ad view and an ad tap cannot count as gameplay.
- Hide and stop requests immediately after Remove Ads becomes confirmed.
- Collapse or resize the host only between runs. On compact devices, suppress it for the run if the accepted minimum board size cannot coexist with the reserved host.
- Use only official test IDs outside production and make Release fail if test/live configuration is wrong.
- Provide a route to report inappropriate ads as required by the release policy.

Important policy/UX gate: common mobile-ad guidance discourages clickable banners beside continuously interactive gameplay. The accepted first release reserves this exact bottom host but fills it only on the main menu and terminal results. A live banner during Arcade or Zen requires a new explicit product and ad-policy decision, plus device evidence that it cannot encourage accidental taps.

Current implementation fills only main-menu and terminal-results hosts. Active Arcade/Zen always keeps the same empty 50-point slot. Loading, no-fill, consent failure, offline state, and ad-free teardown leave that frame stable. There is no app-owned refresh timer; GMA owns supported banner refresh behavior.

## Interstitial cadence

- Treat Arcade Game Over and deliberate **End run** into Zen Results as terminal sessions. Restarts, menu exits, background abandonment, crashes, targets, and duplicate result rendering do not count.
- Keep one combined, versioned, persistent completion counter and recent app-local completion UUIDs. The tenth completion makes an interstitial due; later completions saturate at ten while it remains due.
- Offer the due interstitial only from that completion's results surface after any ranked finish request reaches success or failure. Never present on launch, foreground, login, consent dismissal, purchase dismissal, or active gameplay.
- No-fill, offline, unloaded, expired, and presentation-failure paths continue immediately and retain the due state for a later qualifying result.
- Reset only from GMA's successful presentation-began callback. Dismissal discards the used ad and starts the next preload.
- A server-confirmed ad-free state clears the operational cadence and suppresses future increments/presentation.

## Consent and tracking

If Google Mobile Ads is selected:

1. Request updated UMP consent information on every launch before any ad request.
2. Present required forms and expose Privacy Options when required.
3. Load ads only when the SDK reports that ads may be requested.
4. Do not initialize or preload live ads before consent/age treatment is ready.
5. Put the required `GADApplicationIdentifier` and current `SKAdNetworkItems` in the accepted build configuration.
6. For GMA ad requests, configure `ageRestrictedTreatment`/TFAT and max content rating before SDK initialization; its legacy TFCD/TFUA request properties are deprecated. Separately set UMP `RequestParameters.isTaggedForUnderAgeOfConsent` before the consent-information update when the accepted policy requires it—UMP still uses that property and does not forward the signal to GMA.

ATT is separate from UMP/GDPR consent. Request ATT only if the final configuration performs cross-app/site tracking or uses IDFA. Contextual/nontracking advertising is the recommended starting point. No feature, reward, or purchase may depend on accepting ATT.

The current adapter sets maximum content rating to General, leaves age treatment unspecified pending the accepted audience policy, disables GMA publisher personalization and publisher first-party ID, never requests ATT, and adds no tracking purpose string. This runtime choice does not erase the pinned Google SDK privacy-manifest declarations: GMA 13.6.0 declares linked advertising/product/coarse-location data and a linked Device ID marked for tracking; UMP 3.1.0 declares unlinked coarse location, performance, and product interaction. App Store privacy answers and the archive aggregate privacy report must reflect the resolved SDKs rather than infer “no tracking” merely from the absence of ATT.

The real AdMob App ID is present in every configuration so UMP can resolve PimPoPom's dashboard message. Debug and named Staging use Google demo units. Owner Ads QA uses ignored production units plus the hashed test-device identifier printed by GMA, and every owner creative must visibly say **Test mode** before any interaction. Checked-in Release is disabled; live units are an explicit controlled-archive input and cannot coexist with a test hash. The committed 50-entry `SKAdNetworkItems` snapshot was reviewed against Google's official iOS setup list on 2026-07-19 and must be refreshed whenever the pinned GMA version or Google's list changes.

## StoreKit product model

Authority boundary: Apple's signed StoreKit transaction/current-entitlement state proves payment, refund, revocation, and the Remove Ads entitlement. PimPoPom verifies that signed state rather than trusting a local boolean or ad SDK. The server independently verifies and owns all account-bound coin credit/ledger state and any optional cross-profile projection of Remove Ads.

| Capability | Proposed type | Authority |
| --- | --- | --- |
| Remove Ads | Non-consumable | App Store transaction/current entitlement, reconciled by app/server |
| Coin pack | Consumable | App Store-signed transaction verified and credited once by server |
| Pet/theme | In-game coin spend, not separate IAP | Server catalog, ownership transaction, and ledger |

The accepted products are:

| Product ID | Type | US price point | Verified result |
| --- | --- | ---: | --- |
| `com.otcsoftware.pimpopom.coins.50.v1` | Consumable | $2.99 | 50 purchased coins plus account-bound ad-free |
| `com.otcsoftware.pimpopom.coins.100.v1` | Consumable | $4.99 | 100 purchased coins plus account-bound ad-free |
| `com.otcsoftware.pimpopom.coins.500.v1` | Consumable | $9.99 | 500 purchased coins plus account-bound ad-free |
| `com.otcsoftware.pimpopom.coins.1000.v1` | Consumable | $14.99 | 1,000 purchased coins plus account-bound ad-free |
| `com.otcsoftware.pimpopom.removeads.lifetime` | Non-consumable | $1.99 | Apple-restorable, Family-Shareable ad-free; no coins |

Every valid direct coin purchase contributes an account-bound ad-free entitlement source. Only the standalone non-consumable participates in Apple's Restore Purchases and Family Sharing; family members receive no coins. “Forever” means non-expiring while at least one verified, unrefunded source remains, not an irreversible profile flag. StoreKit remains authoritative for localized storefront names and `displayPrice`, including localized Canadian pricing.

## Recommended paid-value ledger

Selling coins invalidates the old assumption that every coin came from verified play or achievement rewards. Recommended design:

- retain one simple displayed spendable total, but track **earned** and **purchased** provenance separately on the server;
- create immutable `iap_coin_credit`, refund/reversal, and split-debit events keyed by App Store transaction ID and economy generation rules designed for paid value;
- spend earned coins first, then purchased coins, and record the exact split on every cosmetic debit;
- preserve the baseline `total_coins_collected` meaning for eligible run credits and claimed achievement rewards, but never increment it for purchased coin credits or let IAP unlock **Collect 5 coins**;
- when a verified-play result is revoked after its earnings were spent, create earned debt that future earned credits repay; do not silently reduce the purchased bucket;
- when Apple refunds a consumed coin pack, apply an explicit refund policy to unused purchased balance and any spent shortfall without falsifying the ledger or silently deleting unrelated earned value;
- do not let an administrative reward reset erase StoreKit transaction history or paid entitlement;
- reconcile server notifications idempotently and retain support/audit evidence under the privacy retention policy.

P-031 accepts this as the technical economy rule. On an Apple refund, remove the exact transaction's unspent purchased value, revoke only cosmetics whose recorded debit was actually funded by that transaction, restore unrelated earned allocations, and expose any remaining shortfall as `refundDebt`. Future credits clear refund debt before becoming spendable. `REFUND_REVERSED` restores credit and refund-revoked cosmetics idempotently. Remove ad-free only when no other valid source remains. Administrative moderation never erases purchased balances, IAP history, or paid entitlements.

## Purchase flow

1. Fetch products from StoreKit; never hard-code localized price text.
2. Require/confirm the PimPoPom profile for coins and attach its internal UUID as `appAccountToken`.
3. Start purchase and handle success, user cancellation, pending/Ask to Buy, unverified, unavailable, and error states.
4. Locally verify the StoreKit result, send its signed JWS to the server, and await idempotent credit/entitlement acknowledgement.
5. Refresh the server balance/entitlement, then finish the transaction.
6. Listen for transaction updates at launch and while running so interrupted purchases reconcile.
7. Process App Store Server Notifications V2 for refunds, reversals, and lifecycle changes.

The server accepts product and signed transaction identity, never a client-submitted coin quantity, balance, or price.

The initial storefront scope is the United States and Canada. Restrict the app and each IAP separately in App Store Connect. Complete the age-rating questionnaire from actual public-nickname, leaderboard, advertising, and purchase behavior; PimPoPom is not a Kids Category app.

## Data inventory

Expected first-party data:

- internal random player UUID;
- public nickname and confirmation state;
- one-way Apple/Google subject digests, app-session records, and only encrypted provider revocation material strictly required for account deletion;
- ranked attempts, chronological proof events, derived results, ranks, flags, and moderation audit;
- achievements, pets, themes, coin ledger/debt, StoreKit transaction identifiers and status;
- consent state required to operate ads, integrity key metadata, rate-limit/audit logs, and support requests;
- device-local settings for accessibility, audio, haptics, free theme, and nonsecret cache state.

Do not persist raw provider subjects, Google/Apple display names, passwords, advertising identifiers unless explicitly required by accepted tracking design, or email addresses merely because a provider returns one. Provider tokens are exchanged immediately; any server-side refresh/revocation credential retained solely for required disconnect/deletion is encrypted, access-controlled, purpose-limited, and covered by the retention policy.

Third-party SDK data must be inventoried from the exact pinned version, including its privacy manifest and current vendor disclosure.

## Privacy deliverables

Before TestFlight external beta or App Store review:

- valid `PrivacyInfo.xcprivacy` covering first-party collection and required-reason APIs;
- reviewed privacy manifests/signatures for every third-party SDK;
- App Store privacy labels matching actual app and SDK behavior;
- public Privacy Policy, Terms, Support, account deletion, and privacy-choice URLs;
- data retention/deletion schedule and a tested in-app deletion flow;
- provider token revocation and account-linking/merge support procedure;
- nickname filtering/reporting/blocking/moderation policy;
- current age rating and child/teen advertising policy;
- ATT purpose string only if ATT is actually requested;
- DSAR/export/correction process for launch regions where required.

## Official references

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [StoreKit 2](https://developer.apple.com/storekit/)
- [In-App Purchase configuration](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/)
- [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app)
- [Google UMP for iOS](https://developers.google.com/admob/ios/privacy)
- [Google iOS banner guidance](https://developers.google.com/admob/ios/banner)
