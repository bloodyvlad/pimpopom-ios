# Native API contract

Status: two layers. The first section records the deployed compatibility surface used by the internal alpha under P-014 and the named first TestFlight cohort under P-027. The later `mobile-v1` surface remains the production direction for broader external distribution.

## Current internal-alpha compatibility surface

Base URL: `https://speedytapper.otcsoft.com`. Live health and signed-out session probes on 2026-07-20 confirmed Season 1, public access, Apple identity enabled for `com.otcsoftware.pimpopom`, and the additive identity/wallet/ad-free/StoreKit session shape. The recorded backend release is annotated tag `hostinger-20260720-1` at commit `1debeaf16210bc6d2fbe9fd406adc158c9e4aa80`; its compatibility allowlist retains the native client's `20260719-1` ranked-proof build.

| Method and path | Purpose | Native behavior |
| --- | --- | --- |
| `GET /api/session` | Cookie/CSRF bootstrap and profile summary | Always call before mutation; retain returned CSRF in memory |
| `POST /api/auth/google` | Explicit Google login, registration, or reauthentication | Native body includes `credential` plus `intent: login\|register\|reauth`; omission is legacy-browser compatibility only |
| `POST /api/auth/apple/challenge` | Single-use Apple nonce/state | Exact body contains `intent: login\|register\|link\|reauth` |
| `POST /api/auth/apple` | Complete native Apple authorization | Exact body contains challenge ID/state plus Apple identity token and one-time authorization code |
| `POST /api/profile/identities/google` | Link Google to the current UUID | Recently authenticated CSRF mutation; exact body contains `credential` |
| `POST /api/profile/game-center/challenge` | Issue Game Center link challenge | Authenticated CSRF mutation with `{}`; deployed compatibility PHP may still require recent primary auth until the P-054 backend task ships |
| `POST /api/profile/game-center` | Verify and reconcile signed `teamPlayerID` | Exact challenge/proof tuple; link-only secondary identity; current-profile-wins reassignment is backend follow-up |
| `POST /api/logout` | End PHP session | CSRF mutation |
| `GET`, `PATCH /api/profile?mode=normal` | Profile and nickname | PATCH body contains only `nickname` |
| `POST /api/profile/nickname/availability` | Check a public player name | Authenticated CSRF mutation; exact body `{"nickname":"<candidate>"}`; this check does not reserve the name |
| `GET /api/leaderboard?mode=normal\|zen` | Public/shared ranks | Available signed out |
| `POST /api/runs` | Issue ranked Arcade ticket | Body `{"mode":"normal","buildId":"20260719-1"}` |
| `POST /api/runs/abandon` | Idempotent discard | Body contains `runId` |
| `POST /api/runs/finish` | Replay proof and save result | Ticket metadata plus integer proof tuples only |
| `GET /api/achievements` | Five-goal catalog, player state, and balance | Public; signed out returns the locked catalog, while authenticated reads return server-authoritative states/counts and `coinBalance` |
| `POST /api/achievements/claim` | Idempotently claim an unlocked reward | Authenticated CSRF mutation; exact body `{"id":"<stable-id>"}`; 201 first claim, 200 duplicate |
| `GET /api/themes` | Theme catalog, profile, and balance | Public; response includes server IDs/names/prices, profile or null, and `coinBalance` |
| `POST /api/themes/select` | Buy or select a theme | Authenticated CSRF mutation; body `{"themeId":"<id>"}`; server returns purchase flag, paid price, profile, and balance |
| `GET /api/pets` | Pet catalog, profile, and balance | Public; response includes server IDs/names/prices, profile or null, and `coinBalance` |
| `POST /api/pets/select` | Buy/select/show a pet | Authenticated CSRF mutation; body `{"petId":"<id>"}`; server returns purchase flag, paid price, profile, and balance |
| `PATCH /api/pets/selection` | Hide/show current pet | Authenticated CSRF mutation; body `{"petId":"<id>","visible":true\|false}` |

The native client uses one long-lived default `URLSession` with shared cookie storage, `Accept: application/json`, JSON content type on bodies, and `X-SpeedyTapper-CSRF` on mutations. It sends no browser `Origin`. Login rotates the session binding, so do not log in again between ranked start and finish. Browser and native sessions are separate, while the single open run attempt is player-global.

Concurrent session bootstrap is coalesced. Login, logout, nickname, achievement, theme, and pet mutations carry a client-side session/player generation; a superseded response is rejected instead of being attached to a newer account. Achievement claims are serialized with other account mutations, and an expired 401/403 triggers session reconciliation before the player may retry. Theme and pet mutations are also serialized across both shops. These client checks prevent stale presentation state but do not replace server authentication, transactions, or idempotency.

Public player names contain no Unicode whitespace anywhere. iOS rejects Unicode scalar whitespace before a request and, after a 400 ms editing pause, posts the current candidate to `/api/profile/nickname/availability`. A `200` response contains the server-normalized `nickname` plus `available`; checking the signed-in player's unchanged current name returns `available: true`. `available: false` disables Save and renders **This player name is already taken.** A `400` whitespace rejection renders the server validation error. Cancellation or transport/server failure is never interpreted as availability: the UI shows a temporary validation-unavailable state and permits the authoritative PATCH.

Availability is advisory and does not reserve a name. `PATCH /api/profile?mode=normal` remains the only write and can lose a race after a successful check. Any save-time `409` is rendered as the same exact taken-name state. The parent PHP release owns normalization, confirmed-name uniqueness, owner exclusion, and the database constraint; an iOS upload must not be described as end-to-end unique until that backend release is deployed.

`GET /api/session` and `POST /api/runs/finish` may include an additive `achievementSnapshot`. The current native models intentionally do not consume it. Session decoding consumes `appleSignIn`, `identityBindings`, `wallet`, `adFree`, and `storeKit` while remaining compatible with older responses; synthesized `Codable` decoding ignores all other unknown response keys while retaining every required session/finish field.

Signed-out Google first tries explicit `login`; a `409` requires a separate **Create New Profile** confirmation before `register`. Signed-out Apple uses explicit `register` as the backend's idempotent login-or-create intent in one native authorization: an existing Apple subject returns its existing UUID, while an unknown subject creates one without a second application prompt. Neither path merges identities. To retain an existing wallet, the player signs in through an already linked method and explicitly links the second provider. Email, relay email, nickname, device, StoreKit binding, and Game Center identity are never account-merge evidence. Apple challenges are five-minute, session-bound, and single-use; the app passes their raw nonce and state unchanged into `ASAuthorizationAppleIDRequest`, requests no name/email scopes, keeps credentials in memory only, and submits the exact returned UTF-8 token/code. Google and Apple `reauth` responses must retain the expected internal player UUID before account deletion or another sensitive link proceeds.

The achievement client validates unique nonempty catalog entries, positive rewards, consistent totals/states, the exact claimed item, duplicate marker, nominal `coinsEarned`, and nonnegative balance before changing presentation or profile coins. The five bundled definitions are signed-out/error fallback copy only; they never authorize unlocks or rewards. Server-side debt can absorb a credited reward, so `coinBalance` rather than arithmetic on `coinsEarned` is the local economy truth.

Google configuration uses a new iOS OAuth client whose bundle ID matches the app plus the existing Web OAuth client as Google `serverClientID`. The returned ID token therefore retains the audience the PHP verifier already accepts. OAuth client IDs are public configuration; no OAuth client secret ships in the app.

Ranked compatibility is fixed to ruleset `reaction-proof-v2`, proof version 1, a 256 KiB body cap, and 10,000 events. P-025 temporarily passes the currently deployed build ID. Arcade must first bootstrap the PHP session; a signed-in confirmed session must also obtain a ranked ticket before gameplay begins. A session or ticket failure is blocking and retryable rather than a silent downgrade. After `/api/runs/finish`, a `verified` result is accepted only when `submittedEntryId` equals that ticket's `runId`; `review` and `quarantined` confirm persistence but remain intentionally absent from public ranking. P-027 permits this production-compatible path only for the first direct-email TestFlight owner/QA cohort. It must still be replaced before public-link beta expansion or App Store distribution, and immediately if the server changes its accepted build.

The deployed compatibility backend now exposes StoreKit credit and account-deletion routes described below. The native StoreKit client uses them only for an authenticated, bound profile and never grants local value before a validated server acknowledgement. Achievement state/rewards, StoreKit wallet and entitlement state, pet/theme prices, ownership, selection, and balance are always taken from the server response; client fallback catalogs are display/offline continuity only.

### Game Center boundary

P-054 keeps Game Center authentication independent of primary PimPoPom authentication but installs `GKLocalPlayer.local.authenticateHandler` at app launch. Apple's standard authentication presentation may appear when required; cancellation, restrictions, Apple sign-out, network failure, and service failure remain nonblocking. Successful Game Center authentication alone cannot log in, register, access a wallet, authorize an economy/profile route, or create a PimPoPom profile. The app stores no local participation preference.

When a primary PimPoPom session and an authenticated GameKit player coexist, iOS first confirms `GKLocalPlayer.local.scopedIDsArePersistent()`. Transient IDs are rejected locally and never sent. It refreshes `GET /api/session`, posts `{}` with the current CSRF token to `/api/profile/game-center/challenge`, and then—and only then—obtains fresh GameKit identity-verification material. It posts the exact challenge ID, `teamPlayerId`, persistent `gamePlayerId`, `publish: true`, HTTPS public-key URL, standard padded Base64 signature/salt, and integer millisecond timestamp to `/api/profile/game-center`. An unchanged successful profile/player context is deduplicated in-process; profile, Game Center player, foreground, or deferred-failure changes can trigger a later reconciliation. A server `mirrorReady` value never substitutes for proof when reconciliation is required.

The server still validates Apple's certificate chain, challenge/timestamp freshness, replay, bundle, and signed team identity. `gamePlayerId` remains client-asserted rather than covered by Apple's ordinary non-Apple-Arcade signature. PHP is responsible for binding and destination policy. The new iOS client treats `401`, `403`, `409`, and `503` link failures as deferred Game Center side effects and does not expose conflict or delivery-operator state in Profile; they never downgrade or block gameplay. It does not retry in a tight loop.

The parent PHP service must separately adopt the current-profile-wins transaction in [`GAME_CENTER_AUTOLINK_PHP_TASK.md`](GAME_CENTER_AUTOLINK_PHP_TASK.md): retain authenticated session/CSRF, fresh challenge/proof, replay protection, encrypted scoped-ID storage, uniqueness, deterministic publication locks, and authoritative outbox backfill, while moving a valid current team/game pair instead of returning an ownership conflict. Until that deployment is verified, the compatibility backend may continue requiring recent primary authentication and may return `403`/`409` for old bindings.

Session and link responses may continue adding a `gameCenter` object with `serverPublicationAvailable`, nullable `preReleased`, `identityLinked`, `publicationEnabled`, `mirrorReady`, `pendingJobs`, `heldJobs`, and `needsReset`; link responses may add `newlyLinked`, `gamePlayerIdNewlyBound`, or another additive reassignment marker. Unknown fields remain tolerated. The candidate Profile deliberately does not render these delivery states. It shows only **Game Center** and a **See stats** button when Apple's dashboard can be presented. `GKGameCenterViewController(state: .dashboard)` remains delegate-dismissed so it can be reopened repeatedly without restarting the app.

The compatibility `DELETE /api/profile/game-center/publication` route may remain available for older clients and support tooling, but the P-054 iOS client has no Disable control and does not call it. Apple account selection remains managed by iOS Settings. Account deletion still removes the server binding and pending publication state. The App Store Connect API credential remains server-only.

PHP alone mirrors the protocol-verified Arcade all-time best and eligible achievements through its environment-aware, idempotent outbox. The app never calls `GKLeaderboard.submitScore` or `GKAchievement.report`. Use the server allowlist rather than constructing vendor IDs from arbitrary response data:

| PimPoPom ID | Game Center vendor ID | Points |
| --- | --- | ---: |
| `complete_arcade` | `com.otcsoftware.pimpopom.achievement.complete_arcade` | 10 |
| `godlike_speed` | `com.otcsoftware.pimpopom.achievement.godlike_speed` | 25 |
| `collect_5_coins` | `com.otcsoftware.pimpopom.achievement.collect_5_coins` | 15 |
| `score_over_100k` | `com.otcsoftware.pimpopom.achievement.score_over_100k` | 40 |
| `buy_a_pet` | `com.otcsoftware.pimpopom.achievement.buy_a_pet` | 10 |

The backend exposes binary locked/claimable/claimed state, not trustworthy numeric progress. PHP reports only monotonic 100% completion when an item first becomes `claimable` or is already `claimed`; it never publishes 0% or treats the separate coin-reward claim as the unlock. A verified automatic binding reconciles historical eligibility before backfill and enqueues later unlocks transactionally. TestFlight uses Apple's prerelease lane; production uses the production lane. Reassignment stops future delivery to the displaced destination but cannot erase leaderboard or achievement history Apple already accepted there. Account deletion removes binding, publication state, and pending work without calling Apple's reset-all-achievements API.

## Baseline gap

The migration source service currently uses:

- same-origin secure HTTP-only PHP session cookies;
- a CSRF token/header for mutations;
- a Google **Web** client ID and browser credential flow;
- one browser-session-bound ranked attempt per player;
- an exact accepted build (`20260719-1` for this native client on deployed service `20260719-2` at the current audit);
- ruleset `reaction-proof-v2`, proof version 1, a 256 KiB body cap, and 10,000 proof-event cap;
- extensionless `/api/*` routes for session, profile, leaderboard, runs, achievements, pets, themes, and administration.

PimPoPom must not pretend to be that browser build. A native `URLSession` client could technically carry cookies, but doing so would leave identity audience, CSRF, session binding, token storage, account linking, app integrity, and native logout/revocation poorly defined. Add a versioned mobile contract instead.

## Compatibility model

Keep these version axes distinct:

| Axis | Example | Purpose |
| --- | --- | --- |
| API version | `mobile-v1` | Request/response and auth shape |
| Client platform | `ios` | Platform-specific policy/telemetry |
| Marketing version | `1.0.0` | Player/App Store version |
| Build number | `42` | Exact binary build |
| Ruleset | `reaction-proof-v2` | Deterministic gameplay rules |
| Proof version | `1` | Event encoding and replay semantics |
| Economy catalog version | server-issued | Products, prices, achievements |

At session/bootstrap, the server returns supported/minimum client, ruleset, proof, maintenance, and catalog information. An unsupported ranked client may still offer local play but cannot silently submit under another version.

## Candidate mobile-v1 route inventory

The cross-repository backend milestone must freeze these paths, JSON Schemas/OpenAPI definitions, status/error codes, and authorization rules before client generation. Renaming is allowed before acceptance, not after a mobile-v1 release.

| Method and candidate path | Purpose | Success |
| --- | --- | ---: |
| `GET /api/mobile/v1/bootstrap` | Compatibility, public catalog versions, session/profile summary | 200 |
| `POST /api/mobile/v1/auth/apple` | Exchange Apple authorization proof | 200/201 |
| `POST /api/mobile/v1/auth/google` | Exchange Google authorization proof | 200/201 |
| `POST /api/mobile/v1/auth/link` | Explicitly link a second provider under recent auth | 200 |
| `POST /api/mobile/v1/session/refresh` | Rotate app access/refresh session | 200 |
| `POST /api/mobile/v1/logout` | Revoke this app session | 204 |
| `DELETE /api/mobile/v1/account` | Start confirmed deletion/revocation workflow | 202 |
| `GET`, `PATCH /api/mobile/v1/profile` | Read profile / confirm public nickname | 200 |
| `GET /api/mobile/v1/leaderboard?mode=normal\|zen` | Top five and authorized context | 200 |
| `POST /api/mobile/v1/runs` | Issue ranked Arcade attempt | 201 |
| `POST /api/mobile/v1/runs/{runId}/abandon` | Idempotently abandon issued attempt | 204 |
| `POST /api/mobile/v1/runs/{runId}/finish` | Replay proof and return exact result/economy | 200 |
| `GET /api/mobile/v1/achievements` | Read active catalog and player state | 200 |
| `POST /api/mobile/v1/achievements/{id}/claim` | Idempotently claim unlocked reward | 200 |
| `GET /api/mobile/v1/pets` | Catalog, ownership, selection, balance | 200 |
| `POST /api/mobile/v1/pets/{id}/select` | Buy/select/show under server price | 200 |
| `PATCH /api/mobile/v1/pets/selection` | Hide/show current selection | 200 |
| `GET /api/mobile/v1/themes` | Catalog, ownership, selection, balance | 200 |
| `POST /api/mobile/v1/themes/{id}/select` | Buy/select under server price | 200 |
| `GET /api/mobile/v1/storekit/catalog` | Map accepted App Store products to server catalog | 200 |
| `POST /api/mobile/v1/storekit/transactions` | Verify/idempotently credit signed transaction | 200 |
| `GET /api/mobile/v1/entitlements` | Reconcile ad-free/current paid state | 200 |
| `POST /api/mobile/v1/integrity/challenges` | Issue one-time App Attest challenge | 201 |

Expected non-success classes are 400 validation, 401 unauthenticated, 403 unauthorized/recent-auth/integrity policy, 404 unknown resource, 409 state/idempotency conflict, 413 body cap, 422 valid shape but rejected proof/transaction, 426 unsupported app/ruleset, 429 rate limit, and 503 maintenance/transient service. The accepted schema must give each case a stable machine code and state whether retry is safe.

## Authentication and sessions

### Provider exchange

Proposed endpoints, names subject to backend review:

- `POST /api/mobile/v1/auth/apple`
- `POST /api/mobile/v1/auth/google`
- `POST /api/mobile/v1/auth/link`
- `POST /api/mobile/v1/session/refresh`
- `POST /api/mobile/v1/logout`
- `DELETE /api/mobile/v1/account`

Requirements:

1. The app creates provider requests with nonce/state and platform-native UI.
2. The server validates provider signature, issuer, audience, expiry, nonce/state, and authorization code/token semantics.
3. The server maps a one-way provider-subject digest to an internal random player UUID.
4. Provider display name and email never become the public nickname automatically and are not persisted unless a separately justified account requirement is accepted.
5. Provider identity/authorization tokens are exchanged, not reused as PimPoPom sessions. Retain only encrypted server-side refresh or revocation material strictly required to disconnect the provider during account deletion; document its retention and access controls.
6. The server issues short-lived access and revocable refresh sessions. The app stores sensitive session material in Keychain, not `UserDefaults`.
7. Apple and Google identities link only through an explicit, recently authenticated flow. Email equality is never sufficient.
8. Logout revokes the app session and clears Keychain state. Account deletion revokes providers where required and follows the accepted ledger/result retention policy.

Access requests use `Authorization: Bearer <access-token>`. Native bearer mutations do not use browser CSRF, but retain origin-independent replay/idempotency controls and recent-auth gates for destructive operations.

## Common request metadata

Every request carries a generated request ID and nonsecret client metadata, for example:

```json
{
  "client": {
    "platform": "ios",
    "appVersion": "1.0.0",
    "buildNumber": "42",
    "ruleset": "reaction-proof-v2",
    "proofVersion": 1
  }
}
```

Do not send device names, advertising identifiers, email addresses, raw provider subjects, or permanent hardware identifiers as generic metadata.

Mutations that can be retried use a UUID idempotency key. The server stores the operation result against the authenticated player and operation type, detects payload mismatch, and returns the original result for a safe retry.

## Bootstrap/profile response

The native bootstrap response should provide only what the app needs:

- authenticated state and public profile;
- nickname confirmation state;
- coin balances/provenance summary accepted by the economy design;
- ranks and entitlement summary;
- selected/visible pet and selected theme;
- API/ruleset/proof compatibility;
- server time and maintenance state;
- feature/catalog versions;
- whether recent authentication is required for a requested sensitive action.

Never use a client profile flag as authorization for administration, purchases, or moderation. Server routes re-check roles and ownership.

## Ranked run lifecycle

### Start

The client requests a ranked Arcade attempt before first target presentation. Authentication and confirmed public nickname are required. The request includes platform/build/ruleset/proof metadata and, once adopted, an App Attest assertion over a server challenge.

The server:

- verifies compatibility and rate limits;
- abandons the player's earlier issued attempt according to policy;
- issues a random one-time run UUID bound to player, app session, platform, ruleset, proof version, and integrity context;
- returns only rules and timing inputs required by the accepted protocol.

If start fails, PimPoPom may start an explicitly unranked local Arcade run. That result is never upgraded later.

### Abandon

Restart, Main Menu, backgrounding, account change, or a discarded ranked result requests idempotent abandonment. Completed/closed attempts do not change. Local state stops immediately even if the network call fails.

### Finish

The request contains run identity and chronological proof events only. It does not submit authoritative score, duration, ratings, dodges, multiplier, coins, nickname, price, balance, or ownership.

Exact baseline proof-v1 tuple shapes:

| Opcode | Tuple | Notes |
| ---: | --- | --- |
| 0 | `[0, presentedAtMs, targetCell]` | Target presentation |
| 1 | `[1, inputAtMs, handledAtMs, cell]` | Correct input; handled time is not earlier than input |
| 2 | `[2, inputAtMs, handledAtMs, reasonCode, cell]` | Miss; reason 0 empty, 1 wrong, 2 late |
| 3 | `[3, visibleAtMs, decoyId, cell, lifetimeMs]` | Decoy activation |
| 4 | `[4, settledAtMs, decoyId, ...]` | One or more naturally expired decoys |
| 5 | `[5, logicalFinishAtMs, handledAtMs]` | Third-life terminal transition |
| 6 | `[6, opportunityAtMs]` | Decoy opportunity that created nothing |

Times are chronological integer milliseconds from the run start under the proof clock. Complete accepted/invalid arrays belong in versioned golden fixtures; do not hand-author a partial example and treat it as valid. The server replays transitions, derives canonical fields, checks server-clock coverage and cadence, detects duplicate UUIDs and cloned traces, consumes the attempt once, and returns the exact result plus its rank context and economy effects.

Calling finish again with the same run UUID/payload returns the stored result without another rank, achievement, or coin credit. A mismatched retry is rejected.

## Catalog and economy operations

The native equivalents of profile, leaderboard, achievements, pets, and themes retain existing invariants:

- reads return server catalog IDs, localized-independent names/keys, ownership, selection, and authoritative balance;
- purchase/select bodies contain only the stable item ID, never price or balance;
- server transactions lock the player, verify catalog/ownership/balance/generation, write ownership plus ledger plus selection atomically, and return the new state;
- achievement claims use stable IDs and immutable idempotent ledger events;
- historical Zen is read-only and new Zen writes are rejected.

## StoreKit transaction credit

Deployed endpoints: `POST /api/storekit/transactions` and the versioned alias `POST /api/mobile/v1/storekit/transactions`. They are owned by the PHP release recorded above. Both require the existing authenticated cookie and CSRF header.

The app sends:

- `signedTransaction`: the App Store-signed JWS representation from a locally verified StoreKit transaction;
- `appAccountToken`: the current authenticated server-issued UUID binding.

The request contains no client product identifier, coin quantity, price, balance, environment, or separate idempotency key. Those values and the globally unique transaction identity come only from Apple's signed payload; the server rejects unknown request fields.

The server verifies Apple signature/chain and bundle/product/environment/account binding, checks immutable transaction ID and refund/revocation state, credits the matching catalog pack once, appends ledger provenance, and returns `transactionId`, `status`, `duplicate`, `wallet`, and `adFree`. It never accepts a submitted coin quantity or localized price.

Only after server acknowledgement does the client finish the consumable transaction. Unacknowledged verified transactions remain recoverable through `Transaction.updates`/unfinished transaction reconciliation.

Remove Ads uses current StoreKit entitlement state plus server reconciliation if cross-platform/profile visibility is desired. The ad SDK never decides entitlement.

## Account deletion

Deployed route: `DELETE /api/profile`, with aliases `/api/account` and `/api/mobile/v1/account`. It uses the existing authenticated cookie and CSRF header and accepts only `{"confirmation":"DELETE MY ACCOUNT"}`. The server additionally requires matching Google or Apple primary authentication within the previous 15 minutes. A valid response confirms `deleted: true` and `authenticated: false`, revokes retained Apple authorization when applicable, destroys the PHP session, removes the Game Center binding, and may include additive paid-evidence retention counts. The native client ignores unknown fields and clears local identity only after validating those two flags.

## App Attest

Adopt challenge-based App Attest for ranked starts/finishes and purchase-credit requests after the ordinary contract is stable:

1. Server issues a unique expiring challenge.
2. App hashes the challenge plus canonical request data and creates an assertion.
3. Server validates the assertion, counter, app identity, and challenge exactly once.
4. Unsupported devices and transient Apple service failures follow an accepted risk policy; the client does not fabricate success.

Attestation validates an app instance, not human input. Keep proof replay, rate limits, trace detection, and moderation.

## Errors and retries

Use one nonlocalized machine-readable envelope:

```json
{
  "error": {
    "code": "nickname_required",
    "message": "A confirmed nickname is required.",
    "requestId": "uuid",
    "retryable": false,
    "retryAfterSeconds": null
  }
}
```

The app localizes UI by `code`; server text is diagnostic fallback. Distinguish authentication, recent-auth, compatibility, validation, conflict, insufficient funds, rate limit, maintenance, review, and transient service failures. Respect `Retry-After`; never retry purchases or run finish blindly without the same idempotency identity.

## Transport, logging, and retention

- HTTPS only; do not weaken platform trust or add ad-hoc certificate bypasses.
- Use bounded request/response sizes and timeouts. Redact authorization, provider tokens, StoreKit JWS, attestation objects, raw proof bodies, and private identifiers from logs.
- Cache only nonsecret presentation/catalog data with explicit expiry. A stale cache never grants entitlement, balance, ownership, or rank.
- Define deletion/retention for profiles, identity mappings, results, proofs, ledgers, purchases, moderation, integrity signals, and logs before release.

## Contract testing

- Store language-neutral JSON fixtures in this repository and the backend repository.
- Run the same accepted/invalid proof vectors in Swift and PHP.
- Validate schema compatibility and error codes in CI.
- Test staging with provider sandbox/test users, StoreKit sandbox, clock skew, duplicate delivery, cancellation, timeouts, account switching, app reinstall, and old supported clients.
- Deploy backend compatibility before distributing a client that depends on it, and keep the prior supported API/ruleset until its release window closes.
