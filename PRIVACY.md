# PimPoPom privacy status

This is an engineering privacy inventory, **not yet the final public Privacy Policy**. The seller identity, support contact, launch regions, retention schedule, ad vendor/configuration, analytics, age strategy, and account-deletion details must be accepted before public release.

PimPoPom is designed to minimize account data. The intended first-party profile stores an internal random identifier, a player-chosen public nickname, one-way identity-provider subject digests, gameplay/ranking records, cosmetic/economy state, and purchase audit information needed to provide and secure the service. It should not store passwords, raw Google/Apple subject identifiers, provider display names, or email addresses merely because a provider returns them. Provider tokens are exchanged rather than used as PimPoPom sessions; only encrypted revocation material strictly required to disconnect an identity during account deletion may be retained under a documented policy.

Local practice should work without an account. Ranked results, durable progression, coin purchases, and cross-device ownership require an account. The intended native contract will verify Sign in with Apple and Google identity on the server, and account linking will be explicit; that contract is not implemented yet.

Game Center authentication is optional and independent. The current app reads Apple's scoped player identifiers and display name only to show connection state, and can obtain a short-lived identity-verification signature for a future explicit server binding. It does not persist or log those values and does not submit Game Center scores. Before the server-fed mirror is enabled, the final privacy inventory and deletion/unlink flow must cover the one-to-one Game Center binding and Apple's leaderboard retention behavior.

Advertising and consent behavior is not final. The recommended starting point is contextual/nontracking advertising with region- and age-appropriate consent, no ATT prompt unless tracking is actually used, and no ad request before the consent system permits it. Remove Ads is planned as an App Store non-consumable purchase.

The release must provide an in-app account-deletion path and explain which immutable financial, anti-fraud, leaderboard, and moderation records must be retained or anonymized for legitimate/legal purposes. See [`docs/MONETIZATION_AND_PRIVACY.md`](docs/MONETIZATION_AND_PRIVACY.md) for the working inventory and release gates.
