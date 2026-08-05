# PimPoPom privacy status

This is the current engineering inventory, not the final public Privacy Policy.

Local Arcade and Zen work without an account. Ranked results, durable progression,
Multiplayer, coin purchases, and cross-device ownership require the relevant
profile/identity gates.

The first-party service stores only the data needed to operate and protect the game:
an internal random UUID, confirmed public nickname, one-way Apple/Google subject
digests, sessions, narrowly required encrypted Apple revocation material, hashed
Game Center binding/destination data, gameplay proofs/transcripts/results,
moderation/publication state, achievements/cosmetics/coin ledger, StoreKit status,
consent/ad-free state, and bounded security/support records.

PimPoPom does not store passwords, provider display names, email/relay addresses,
raw provider subjects/tokens, or raw Game Center IDs merely because they are
available. Apple and Google providers never merge profiles by email, nickname,
device, StoreKit, or Game Center. Game Center authenticates independently at launch,
then silently reconciles as a secondary link after primary sign-in; it cannot log
into a wallet. PHP, not iOS, publishes allowlisted scores and achievements.

Advertising starts only after current UMP permission and authoritative non-ad-free
state. The app does not request ATT or access IDFA. Debug/nonowner beta uses Google
demo units; owner production units run only in registered Test mode; checked-in
Release is disabled. SDK privacy manifests still govern App Store disclosure.

StoreKit-signed transactions are reconciled with the source-aware server ledger.
Every direct coin pack and the standalone Remove Ads product can be an ad-free
source. Refund/revocation removes ad-free only after the final valid source ends.

Before production, publish and verify reviewed Privacy, Support, account-deletion,
and Terms pages; finalize seller/contact, retention/anonymization, regions, age/ad
policy, moderation/reporting, DSAR, `app-ads.txt`, and archive-derived App Store
privacy answers. See [MONETIZATION_AND_PRIVACY](docs/MONETIZATION_AND_PRIVACY.md).
