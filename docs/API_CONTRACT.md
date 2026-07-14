# Native API contract

Status: design requirements and proposed native surface. The deployed server implementation remains authoritative; examples below are not live endpoints until backend work accepts them.

## Baseline gap

The migration source service currently uses:

- same-origin secure HTTP-only PHP session cookies;
- a CSRF token/header for mutations;
- a Google **Web** client ID and browser credential flow;
- one browser-session-bound ranked attempt per player;
- an exact accepted web build (`20260714-11` at the frozen baseline);
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

Proposed endpoint: `POST /api/mobile/v1/storekit/transactions`.

The app sends:

- App Store-signed JWS representation from a locally verified StoreKit transaction;
- product identifier;
- expected authenticated `appAccountToken` binding;
- environment and app transaction context available in the signed payload;
- operation idempotency key;
- integrity assertion if required.

The server verifies Apple signature/chain and bundle/product/environment/account binding, checks immutable transaction ID and refund/revocation state, credits the matching catalog pack once, appends ledger provenance, and returns server balance. It never accepts a submitted coin quantity or localized price.

Only after server acknowledgement does the client finish the consumable transaction. Unacknowledged verified transactions remain recoverable through `Transaction.updates`/unfinished transaction reconciliation.

Remove Ads uses current StoreKit entitlement state plus server reconciliation if cross-platform/profile visibility is desired. The ad SDK never decides entitlement.

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
