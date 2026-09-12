# Monetization and privacy contract

StoreKit, the source-aware server ledger, AdMob, and UMP are implemented. This file
records current behavior and remaining public-release gates.

## Authority

- Apple-signed StoreKit state proves purchase, entitlement, refund, and revocation.
- PHP verifies/idempotently records each account-bound transaction and owns coin
  balances, earned/purchased provenance, debt, catalog prices, cosmetics, and
  account-bound ad-free sources.
- The client never trusts a local amount, price, balance, ownership, ad-free flag,
  or unverified transaction. Local catalogs are presentation/test fallbacks only.
- Anonymous users can play local Arcade/Zen but cannot purchase coins or own durable
  value. Declining optional consent never blocks gameplay or purchases.

## StoreKit catalog

| Product | Type | US price | Current result |
| --- | --- | ---: | --- |
| `com.otcsoftware.pimpopom.coins.50.v1` | consumable | $2.99 | 50 purchased coins + account ad-free |
| `com.otcsoftware.pimpopom.coins.100.v1` | consumable | $4.99 | 100 purchased coins + account ad-free |
| `com.otcsoftware.pimpopom.coins.500.v1` | consumable | $9.99 | 500 purchased coins + account ad-free |
| `com.otcsoftware.pimpopom.coins.1000.v1` | consumable | $14.99 | 1,000 purchased coins + account ad-free |
| `com.otcsoftware.pimpopom.removeads.lifetime` | non-consumable | $1.99 | Apple-restorable, Family-Shareable ad-free |

StoreKit supplies localized product names and prices. Every valid direct coin pack
is an independent nonexpiring ad-free source; spending the coins does not restore
ads. Only the standalone product participates in Restore Purchases and Family
Sharing, and family members receive no coins.

Purchase flow: require the current profile/app-account token, obtain and locally
verify StoreKit's signed result, submit its JWS to PHP, validate the authoritative
wallet/entitlement response, then finish the transaction. Pending, cancellation,
unverified, duplicate, interrupted, account-mismatch, refund, and reversal states
remain explicit and idempotent.

## Ledger rules

- Earned and purchased provenance remains separate under one displayed balance.
- Spend earned value first, then purchased value, recording the split.
- StoreKit credits never increment `total_coins_collected` or unlock play goals.
- Revoked play earnings create earned debt rather than consuming purchased value.
- A refunded pack removes its remaining purchased allocation and only cosmetics
  funded by that lot; unresolved shortfall becomes refund debt.
- Future eligible credits clear debt first. Reversal restores credit and eligible
  cosmetics idempotently.
- Moderation/reset never erases transaction history, purchased value, or a valid
  paid entitlement.

## Advertising

Advertising is outside the reaction board. Eligible menu, Arcade/Zen gameplay, and
terminal Results share one centered fixed 320×50 banner. An ad-supported run freezes
its footer reservation below the Speed Bar for the run; fill, no-fill, consent,
network, and mid-run entitlement changes cannot move the board. A confirmed ad-free
change removes the creative/accessibility surface immediately and retains only
invisible spacing until the current run leaves.

The combined Arcade/Zen completion counter makes an interstitial due on the third
eligible terminal result. Restart, abandonment, backgrounding, duplicate rendering,
and active play do not count. Present only from Results after ranked finish settles
or fails. Reset the due state only when presentation begins; no-fill/offline/error
keeps it due.

### Consent and configurations

1. Eligible launches refresh UMP before any ad request. Same-profile session
   refreshes reuse the current policy result. A resolved different/anonymous
   account or runtime identity loss requires age reconfirmation and a fresh
   age-policy consent flow; an initial unresolved offline lookup retains the local
   age choice while advertising stays blocked by account uncertainty.
2. Start GMA only when UMP says ads may be requested and PHP has resolved the
   session as not ad-free. Unknown/ad-free state starts no inventory.
3. Expose Privacy Options when required, including eligible ad-free and unresolved
   accounts. Core play and purchases do not depend on
   optional tracking consent.
4. Maximum content rating is General; publisher personalization and first-party ID
   are disabled. The app does not request ATT or access IDFA.

| Build lane | Inventory |
| --- | --- |
| Debug | Official Google demo units |
| Staging/TestFlight | Demo by default; committed owner fingerprints select production units with registered Test-mode device ID |
| Owner Ads QA | Cable-only production units with registered Test-mode device ID |
| Checked-in Release | Disabled; live values require ignored private config and explicit authority |

No production-unit creative may be touched unless it visibly says **Test mode**.

## Candidate-31 age handling

The owner approved restricted advertising for ages 13–17 and retained the
three-game interstitial cadence. The candidate adds neutral local age selection,
no birthday/country collection, and blocking before Root startup for unknown or
under-13 players. Ages 13–15 receive UMP under-consent true plus GMA child treatment;
16–17 receive normal regional UMP flow plus GMA teen treatment; adults retain the
restrictive existing adult settings. Sixteen is a conservative product threshold,
not a universal legal age. Account changes require reconfirmation; offline initial
lookup preserves declared age while GMA stays account-gated. The age band is not
sent to the game backend; Google receives age-related consent/ad request signals.
See [implementation, checks and open gates](PRODUCTION_CANDIDATE_31.md).

## Data inventory

First-party service data is limited to what operates and protects the game:

- internal random player UUID and confirmed public nickname;
- one-way Apple/Google subject digests and session records;
- encrypted Apple credential material strictly needed for deletion-time revocation;
- hashed Game Center identities and narrowly required encrypted destination data;
- ranked attempts, proof/transcript events, results, moderation and publication state;
- achievements, cosmetics, coin ledger/debt, StoreKit transaction state;
- consent/ad-free state, rate-limit/security logs, and support/deletion records;
- device-local preferences and nonsecret caches.

Do not retain provider display names, email/relay addresses, passwords, raw provider
subjects/tokens, raw Game Center IDs, signature tuples, complete purchase payloads,
or proof bodies in logs. Provider proofs are exchanged immediately. Game Center is
a secondary link and cannot merge or authenticate a PimPoPom profile.

Pinned SDK privacy manifests remain part of the disclosure even with restrictive
runtime settings. Google Mobile Ads 13.6.0 declares linked advertising/product/
coarse-location data and linked Device ID marked for tracking; UMP 3.1.0 declares
unlinked coarse location, performance, and product interaction. Final App Store
answers must come from the exact archive aggregate report.

## Public-release gates

- publish reviewed Privacy, Support, account-deletion, and Terms URLs;
- align retention/anonymization, provider revocation, moderation/reporting, DSAR,
  seller identity, regions, age rating, and child/teen ad treatment;
- verify UMP dashboard messages, Privacy Options, `app-ads.txt`, and archive privacy
  answers against the live configuration;
- exercise StoreKit purchase, pending, restore, refund/reversal, notifications,
  Family Sharing, account switch, and ad teardown in Sandbox/TestFlight;
- prove banner separation/accidental-touch safety and interstitial cadence on
  physical devices;
- close branding, pet, and Disco public-distribution rights gates.

TestFlight availability does not close these production gates.
