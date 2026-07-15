# PimPoPom decision log

This file records durable product and architecture choices for the native iOS game.

## How to use this log

- **Accepted** decisions define the committed target until superseded.
- **Proposed** decisions are recommendations awaiting explicit acceptance or implementation review.
- **Superseded** decisions remain for history and link to their replacement.
- Plans, experiments, and uncommitted code do not silently change an accepted decision.
- Each new record receives the next stable `P-###` identifier.

## P-001 — Build PimPoPom as a separate native iOS repository

- Date: 2026-07-14
- Status: Accepted

Context: The existing browser game has web, PWA, PHP, and legacy rollback concerns that do not belong in an Xcode release lifecycle.

Decision: Build the native iOS game in its own Git repository. Its app, storefront, icon, support, analytics, and player-facing product name is **PimPoPom**. The local repository may live inside the legacy checkout only while the parent excludes the entire folder locally.

Consequences: Xcode signing, App Store builds, Swift dependencies, and release history stay isolated. Shared backend changes still occur in the repository that owns the backend and must be coordinated through versioned contracts.

Revisit when: A deliberate multi-platform monorepo with generated shared contracts becomes operationally simpler.

## P-002 — Freeze a reviewed migration baseline without modifying it

- Date: 2026-07-14
- Status: Accepted

Context: A moving source makes behavioral parity impossible to measure, while the deployed state cannot be inferred from local documentation alone.

Decision: Use legacy source commit `675551adc715942ce2512c14d396d5d14e763f02` as the initial behavioral and fixture baseline. Treat it as source evidence only, not deployment evidence. Do not implement PimPoPom by editing the legacy repository's current `main` branch.

Consequences: Later web changes are explicit cherry-pick/reconciliation decisions. Every copied asset requires a rights and provenance review. Backend work needed for native clients is separately scoped and reviewed.

Revisit when: A newer source commit is intentionally adopted and parity fixtures are regenerated.

## P-003 — Separate the deterministic game core from Apple frameworks

- Date: 2026-07-14
- Status: Accepted

Context: Reaction timing, scoring, decoys, streaks, Zen behavior, and ranked proof events must be testable without a renderer or device.

Decision: Implement a pure Swift `PimPoPomCore` module with injected monotonic time and randomness. Deterministic tests use a seeded generator; production uses an accepted system random source. A server-supplied gameplay seed would be a new ruleset/proof protocol and requires its own backend decision. Use SwiftUI for application surfaces and SpriteKit for the latency-sensitive reaction scene. Renderers and services consume snapshots and issue commands; they do not duplicate rules.

Consequences: Cross-runtime golden fixtures can prove migration parity. SpriteKit, SwiftUI, ads, audio, networking, and StoreKit can evolve without rewriting the engine.

Revisit when: A measured prototype demonstrates a simpler renderer with equal or better presentation-to-touch correctness on supported 60 Hz and 120 Hz devices.

## P-004 — Extend the authoritative backend through a native versioned contract

- Date: 2026-07-14
- Status: Proposed

Context: The current service owns identity, run tickets, proof replay, ranks, achievements, pets, themes, and coins, but its Google Web login, same-origin cookie, CSRF, session binding, and exact web build gate are browser-oriented.

Decision: Keep one authoritative economy and leaderboard, but add an explicitly versioned native authentication/session and ranked-run contract. Never spoof a web build or copy server authority into the app. Separate client build/version from shared ruleset and proof versions.

Consequences: Native staging endpoints and contract tests are prerequisites for ranked play and purchases. The app can offer local practice while the service is unavailable, but cannot promote that run later.

Revisit when: Product strategy deliberately chooses an iOS-only season or a new shared backend service.

## P-005 — Offer Apple and Google identity with explicit account linking

- Date: 2026-07-14
- Status: Proposed

Context: Existing players use Google, while a native App Store app using third-party primary login generally needs an equivalent privacy-preserving option. Account creation also requires an accessible deletion path for App Store submission.

Decision: Add Sign in with Apple through AuthenticationServices and retain Google Sign-In for cross-platform users. The server validates both providers, maps them to one internal player UUID through a deliberate linking flow, stores provider-subject digests for identity plus only encrypted server-side revocation material a provider requires, and exposes in-app account deletion. Never merge accounts from matching email alone.

Consequences: Native sessions live in Keychain, provider tokens are exchanged rather than used as long-term app sessions, and account deletion/revocation semantics must cover ledger and legally retained audit data.

Revisit when: Google login is removed from PimPoPom or an App Store guideline exception is documented and accepted.

## P-006 — Preserve the established game rules before adding native polish

- Date: 2026-07-14
- Status: Accepted

Context: A platform migration cannot be evaluated if gameplay balance changes at the same time.

Decision: Port the Arcade and Zen behavior in `docs/GAMEPLAY_SPEC.md` with cross-runtime golden fixtures before adding platform-specific polish. User-facing naming changes to PimPoPom; compatibility identifiers such as wire mode `normal` may remain internal.

Consequences: Intentional balance changes require new decisions and fixture updates after parity. Native timing may reduce platform bias, but scoring thresholds do not change silently.

Revisit when: Native playtesting provides measured evidence for a balance change.

## P-007 — Reserve the bottom ad placement without disturbing gameplay

- Date: 2026-07-14
- Status: Accepted

Context: An asynchronously loaded banner can shift the board, intercept reaction taps, overlap safe areas, or create accidental clicks.

Decision: Place the ad container at the absolute bottom of gameplay, below the **Speed streak meter** (the component referred to in the request as the speed rating bar) and above the bottom safe-area inset. The bottom order is pet if visible, Speed streak meter, separator, reserved ad host, then safe-area inset. Reserve its size before a run. Loading, no-fill, consent, offline state, and removal cannot resize an active board or move a target. Ads never overlay gameplay. The initial recommendation keeps this host empty during an active rapid-tapping run and fills ads only on non-active surfaces until the ad provider's policy and accidental-tap review approve otherwise.

Consequences: Compact-device layout must budget for the slot or suppress/collapse it only between runs when the accepted minimum board size cannot be met. Confirmed Remove Ads entitlement may also re-layout only between runs. Touch hit-testing and accessibility tests must prove that the banner cannot receive board touches.

Revisit when: Product evidence favors ads only between runs or a different non-disruptive format.

## P-008 — Provide Remove Ads and Buy Coins entry points

- Date: 2026-07-14
- Status: Accepted

Context: PimPoPom needs clear, platform-compliant monetization entry points without allowing UI state to grant value.

Decision: Put **Remove Ads** in the lower-right safe layout of the main menu. Put **Buy Coins** in both Theme Shop and Pet Shop; both open the same coin-store surface.

Consequences: The proposed implementation uses a StoreKit non-consumable for Remove Ads and StoreKit consumables for coin packs, with server verification and idempotent ledger credit. Restore Purchases must be visible for Remove Ads. Product types/catalog, SKU prices, pack sizes, paid-versus-earned accounting, refunds, revocations, guest purchases, and reset behavior remain release-blocking decisions; a button alone cannot ship the economy.

Revisit when: Monetization research selects a subscription, ad-free paid app, or no-IAP model instead.

## P-009 — Create an original PimPoPom visual and sonic identity

- Date: 2026-07-14
- Status: Accepted

Context: The native game needs its own memorable identity and cannot retain the legacy player-facing brand.

Decision: Generate and review a new PimPoPom logo/app icon system and an original voice-like launch sting: **Pim** at a low pitch, **Po** in the middle, and **Pom** higher. Do not imitate an identifiable person's voice. Retain editable/lossless masters, runtime exports, prompts or performer consent, licences, and hashes.

Consequences: The iOS launch screen remains static. The short cue plays only after activation through the normal audio preference/session lifecycle, never delays interaction, and is tested against silent mode, interruptions, and accessibility expectations.

Revisit when: Brand testing selects another identity or an audio-free launch.

## P-010 — Make StoreKit and the server authoritative for paid value

- Date: 2026-07-14
- Status: Proposed

Context: Selling coins changes the inherited prototype assumption that coins have no real-money value. Client-only verification would permit replay, account mismatch, lost purchases, and destructive moderation of paid value.

Decision: Verify App Store-signed transactions on the server, bind purchases to an internal account with `appAccountToken`, use immutable transaction IDs as idempotency keys, process server notifications/refunds, and keep purchased-value provenance distinct enough to reconcile moderation safely. Never trust a device balance, local entitlement, product price, or unverified transaction.

Consequences: StoreKit sandbox, interruption, pending purchase, duplicate, reinstall, refund, chargeback, and account-deletion tests become release gates. The exact earned/purchased spend order must be accepted before implementation.

Revisit when: Coins are not sold or the entire economy is redesigned.

## P-011 — Use Game Center only as a supplementary social surface

- Date: 2026-07-14
- Status: Proposed

Context: Game Center offers familiar leaderboards and achievements but does not understand the server's proof status, economy generation, moderation, or exact-result context.

Decision: Keep the PimPoPom service authoritative. If a Game Center entry is presented as a mirror of protocol-verified state, bind the authenticated Game Center player identity on the server and submit the verified score/achievement through Apple's supported server API. A client-submitted Game Center board must instead be labeled auxiliary and unverified. Game Center identity never grants profile ownership, coins, purchases, or moderation rights.

Consequences: The app can provide native social discovery without creating a second economy. Failed Game Center submissions are retryable side effects and do not roll back a verified result. A later server quarantine or deletion may not remove an already mirrored Game Center score; correction, season separation, and moderation visibility must be designed before enabling the mirror.

Revisit when: Game Center becomes the only competitive identity or is removed from scope.

## P-012 — Describe ranked results as protocol verified, never bot-proof

- Date: 2026-07-14
- Status: Accepted

Context: Proof replay and App Attest can reject aggregate forgery, invalid transitions, and many modified clients, but cannot prove a human made every physical tap.

Decision: Use **protocol verified** for accepted results. App Attest is a risk signal and request-integrity layer, not proof of humanity.

Consequences: Moderation remains reversible and evidence-based. Marketing, UI, support, and release notes cannot claim bot-proof or human-verified competition.

Revisit when: Independently validated hardware and operational controls support a stronger claim.

## P-013 — Ship an offline technical alpha before platform services

- Date: 2026-07-15
- Status: Superseded by P-014

Context: Xcode and Simulator are installed, and the immediate goal is the shortest route to a native build on an iPhone SE (3rd generation). The current web game has no live ads or purchases, and production ownership, accounting, and legal work can follow once gameplay is stable.

Decision: Build the first PimPoPom alpha as a development-signed, local-only iPhone app. Start with the deterministic Arcade core and SpriteKit scene, complete local Arcade/Zen parity, then validate iPhone SE 2022 and iPhone 13 mini at 60 Hz plus iPhone 13 Pro at adaptive 120 Hz. Use disabled no-network adapters for ads and purchases; add no vendor SDK, StoreKit product, Google sign-in, or backend dependency during this track. The bootstrap uses a replaceable development bundle identifier and automatic signing.

Consequences: Google OAuth is not required to install or play the first alpha. The immediate owner action is only local Apple code signing, device trust, and Developer Mode. Profiles, ranking, economy, shops, final branding/audio, ads, purchases, legal, accounting, storefront, and production credentials remain later phases. Simulator evidence covers builds and layout only; real refresh/touch timing requires the named physical devices.

Revisit when: The local gameplay device matrix passes and the next integrated service slice is selected.

## P-014 — Reuse the deployed PHP contract for the internal native alpha

- Date: 2026-07-15
- Status: Accepted

Context: The owner explicitly accepted shared internal use of the current Hostinger backend, database, players, coins, and leaderboards to reach a playable iPhone build quickly. The deployed service already accepts Google ID tokens whose audience is the existing Web OAuth client, secure cookie sessions with CSRF, and proof-v1 Arcade submissions for build `20260715-1`.

Decision: For owner-only internal testing, PimPoPom may reuse the existing extensionless `/api/*` contract and production Season 1 data. Use one cookie-enabled `URLSession`, bootstrap CSRF through `/api/session`, configure Google Sign-In with a new iOS client ID plus the existing Web client ID as `serverClientID`, and submit only the exact `reaction-proof-v2` proof-version-1 event stream. If sign-in, nickname confirmation, or run-ticket issuance is unavailable, start an explicitly local practice run instead. Do not change or deploy the PHP backend from this repository.

Consequences: The internal binary identifies ranked attempts with the server's accepted Web build ID `20260715-1`; this is a deliberate temporary compatibility exception to P-004, not a claim that PimPoPom is that web binary. Native and browser clients share the one-open-attempt-per-player rule and production data. The Google iOS OAuth ID stays in ignored local configuration. Ads and StoreKit remain disabled. Before any external TestFlight/App Store distribution, replace this exception with an accepted native client/build contract, complete identity/account review, and use staging/synthetic integration data.

Revisit when: The first physical-device alpha works, the deployed web build gate changes, or any build is prepared for someone beyond the owner/internal testers.
