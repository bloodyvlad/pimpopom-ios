# Current native API contract

Arcade, identity and economy retain the existing PHP compatibility surface.
Multiplayer v2 is isolated from historical v1. Build 29 uses gameplay revision 3;
builds 26–28 use revision 2, build 25 retains revision 1 and build 24 uses historical v1.
Exact dated deployment and Apple evidence is in CURRENT_VERSION.md.
PHP implementation/deployment remain owned by the separate PHP repository.

## Build-29 revision-3 extension

Build 29 requires gameplay revision 3 and uses a fresh v2 leaderboard, not the
historical v1 read below. PHP `bf0ef1b030772872775ab64eaedcbaa1b256e0cf` and additive
migration 025 were verified on 2026-09-11. Matching service/client deployment and
Apple state are recorded separately in CURRENT_VERSION.md.

- Protocol/ruleset and ticket authentication stay unchanged. Service identity adds
  nullable `economyGeneration`, captured immutably at actual match start.
- Room discovery revision 2 adds host-only, waiting-phase `setPrivacy` with exact
  room identity/revision. Public/private changes preserve Ready; old clients keep
  discovery 1 and revision-isolated rooms.
- Trusted result revision 2 adds gameplay revision 3, reward policy
  `multiplayer-alive-minute-v1`, competitive/tutorial kind and completed/aborted
  reason. Per-player fields include connected/alive time, survival, peak multiplier
  and start generation. PHP derives credits, never accepts device coin claims.
- `GET /api/mobile/v2/multiplayer/leaderboard` exposes score-only ranks, distinct
  row positions and `verification:server_reported_v2`; unavailable speed-rating
  counts are omitted. Historical v1 rows are neither imported nor deleted.
- Participant-authenticated `GET /api/mobile/v2/multiplayer/results/{matchID}`
  returns that player's immutable saved reward only. Unknown/nonparticipant IDs
  return 404. The client retries briefly and refreshes `/api/session`; it never
  blocks live play or optimistically credits a wallet.
- Two coins accrue per complete eligible minute with independent carry; countdown,
  disconnected time, spectating, tutorial and stale/missing generations earn none.
  Session/profile adds `ranks.multiplayerV2`, preserving the old v1 rank key.

The full [build-29 contract](MP29_GAMEPLAY_TUTORIALS.md) and separate PHP
`docs/MULTIPLAYER_V2_REWARDS.md` specify receipt bounds, idempotence and rollback.
The retained aggregate/history sections below describe released revisions 1/2.

## Transport and session

- Base URL: `https://speedytapper.otcsoft.com`.
- One long-lived default `URLSession` uses shared secure PHP cookies, JSON, and no
  browser `Origin` header.
- Bootstrap with `GET /api/session`. Mutations send the returned token as
  `X-SpeedyTapper-CSRF`.
- Session bootstrap is coalesced. Account/cosmetic mutation generations reject
  stale responses after login/logout/account switches.
- Required fields are validated before presentation; additive unknown response
  fields are tolerated by `Codable` decoding.
- Never log cookies, CSRF, provider proof, Game Center IDs/signatures, StoreKit JWS,
  full proof/transcript bodies, or personal/moderation data.

## Current route inventory

| Method and path | Purpose |
| --- | --- |
| `GET /api/session` | Session, CSRF, profile, identity bindings, wallet, ad-free, StoreKit, ranks |
| `POST /api/auth/google` | Google `login`, `register`, or `reauth` |
| `POST /api/auth/apple/challenge` | Single-use Apple challenge for `login`, `register`, `link`, or `reauth` |
| `POST /api/auth/apple` | Complete Apple authorization with challenge/token/code |
| `POST /api/profile/identities/google` | Explicit recent-auth Google link |
| `POST /api/profile/game-center/challenge` | Fresh Game Center binding/publication challenge |
| `POST /api/profile/game-center` | Verify current Game Center player and reconcile link |
| `POST /api/logout` | End PHP session |
| `GET`, `PATCH /api/profile?mode=normal` | Profile read and authoritative nickname save |
| `POST /api/profile/nickname/availability` | Advisory nickname check |
| `DELETE /api/profile` | Confirmed recent-auth account deletion |
| `GET /api/leaderboard?mode=normal\|zen` | Public top/context window |
| `POST /api/runs` | Issue ranked Arcade ticket |
| `POST /api/runs/abandon` | Idempotently abandon issued run ID |
| `POST /api/runs/finish` | Submit ticket metadata and chronological proof |
| `GET /api/achievements` | Catalog/state/balance |
| `POST /api/achievements/claim` | Idempotent reward claim |
| `GET /api/themes`; `POST /api/themes/select` | Theme catalog and atomic buy/select |
| `GET /api/pets`; `POST /api/pets/select` | Pet catalog and atomic buy/select/show |
| `PATCH /api/pets/selection` | Hide/show selected pet |
| `POST /api/mobile/v1/storekit/transactions` | Verify and reconcile signed StoreKit transaction |

The v2 ticket route and retained historical v1 leaderboard read are specified
below. New v2 room membership, Ready and Start use the authenticated socket.

## Identity and profile

Google first attempts explicit `login`; an unknown subject requires a separate
**Create New Profile** confirmation and `register`. Apple signed-out authorization
uses idempotent `register`: an existing subject returns its UUID; an unknown subject
creates one. Neither flow merges profiles. A player preserves an existing wallet by
signing in with an already-linked provider and explicitly linking the second.

Apple challenges are five-minute, session-bound, and single-use. iOS requests no
name/email scopes, retains proof in memory only, and sends the exact nonce/state,
identity token, and one-time authorization code. Google and Apple `reauth` must
return the expected internal player UUID before deletion or sensitive linking.

Public nicknames are NFKC-normalized Unicode with control and format scalars
removed, contain no Unicode whitespace, and are at most 20 characters after that
normalization. iOS posts an advisory availability check after a 400 ms editing
pause. Availability never reserves a name; `PATCH /api/profile` and the database
uniqueness constraint are authoritative. A save-time `409` is rendered as taken
rather than retried under another identity.

Account deletion sends:

```json
{ "confirmation": "DELETE MY ACCOUNT" }
```

It requires a matching primary reauthentication within 15 minutes. iOS clears
local identity only after `deleted: true` and `authenticated: false`.

## Arcade ranking

Builds 28/29 use compatibility build `20260729-1` and explicitly request
`reaction-proof-v5`, proof 3 for 4×4-only Arcade power-ups. The deployed PHP verifier
retains build 27's v4/proof 3 and older v3/proof 2 unchanged. Migration 025 adds
Multiplayer rewards, not a new Arcade proof contract.
A higher build ID does not select new semantics. See
[ARCADE_POWERUPS](ARCADE_POWERUPS.md).

1. Bootstrap the PHP session.
2. A signed-in confirmed profile requests `/api/runs` before gameplay, with
   `mode, buildId, ruleset, proofVersion`. Only older clients omit the last two;
   the compatible PHP runtime keeps omitted capabilities on v3/proof 2.
3. Reject a ticket whose build, mode, ruleset, proof version, or run identity does
   not match the compiled contract. Failure is blocking/retryable, not local fallback.
4. Submit the engine's chronological integer tuples to `/api/runs/finish`.
5. Accept `verified` only when `submittedEntryId` equals the issued `runId`.
   `review`/`quarantined` confirms persistence but remains withheld.

The server derives every aggregate and coin/achievement effect. Repeating the same
run ID is idempotent. Signed-out and Zen play never create a ranked submission.

## Economy responses

Achievement, theme, pet, StoreKit, wallet, and entitlement presentation changes
only after a structurally valid server response. Prices, quantities, balance,
ownership, selection, unlock, reward, and debt are not accepted from local state.
Server debt may absorb a nominal achievement reward, so returned balance is truth.

The StoreKit request contains only the locally verified signed transaction JWS and
current server-issued `appAccountToken`. It never contains a client coin quantity,
price, or balance. Transaction identity, status, product, wallet, and ad-free
response must match before StoreKit is finished.

## Game Center boundary

GameKit authentication is installed at app launch independently of primary login.
Cancellation, restrictions, Apple sign-out, or service failure never blocks local
Arcade/Zen. Game Center alone cannot create/login to a PimPoPom profile or access
wallet/economy routes.

When primary session and authenticated Game Center coexist, iOS requires persistent
scoped IDs, refreshes the PHP session, requests a fresh challenge, obtains Apple's
identity-verification material, and posts:

- challenge ID;
- signed `teamPlayerId`;
- persistent client-asserted `gamePlayerId`;
- `publish: true`;
- HTTPS public-key URL, padded Base64 signature/salt, and millisecond timestamp.

PHP validates certificate chain, signature, bundle, challenge, timestamp, replay,
and association/publication policy. Apple's ordinary signature covers the team
identity, not the separately supplied game player ID. An unchanged successful
profile/player context is deduplicated in process; account/player/foreground changes
may reconcile again. `401`, `403`, `409`, and `503` link failures are deferred side
effects, not gameplay failures or tight-loop retries.

Profile shows only **Game Center** and **See stats**. Apple owns account selection;
iOS has no manual link/disable surface. PHP alone publishes allowlisted Arcade and
historical v1 Multiplayer best scores and achievement completion. V2 does not
publish scores or achievements. iOS never calls
`GKLeaderboard.submitScore` or `GKAchievement.report`.

## Multiplayer v2 bridge and gameplay revisions

Exact capabilities: `protocolVersion:2`,
`ruleset:"multiplayer-shared-arcade-v2"`, 2–4 seats and at most 900,000 ms.
A higher build ID never selects new semantics. Entry requires a primary PHP
session and confirmed nickname, **not Game Center**.

The build-25 PHP bridge was deployed from commit
`78b51ee6768d6f049d44b3b8c2d2073e0aac34e0`, migration
`023_multiplayer_v2_auth.sql`. It defaults to 503 until valid private
`SPEEDYTAPPER_REALTIME_URL` and `SPEEDYTAPPER_MULTIPLAYER_SERVICE_SECRET`
configuration exists. The released PHP runtime is `f84dc9218b58bb937326be931f2ee969abed4282`;
build 28's Arcade update leaves this bridge and schema 024 unchanged. Deployment
evidence is recorded in CURRENT_VERSION.md and RELEASE.md; historical Railway
bridge/migration evidence remains in Server/DEPLOYMENT_RAILWAY.md.

Builds 26–28 retain this authentication tuple and negotiate `gameplayRevision:2`
in the socket hello/welcome. Omission means revision 1 (build 25). Rooms, browse,
join and resume are revision-isolated. Revised snapshots add neutral hearts;
inputs optionally identify `heartID`, mutually exclusive with `targetID`.
Only revised clients receive an ordered `left` acknowledgment. These capabilities
are explicit protocol fields, never inferred from a build number.

### Cookie-authenticated ticket

`POST /api/mobile/v2/multiplayer/tickets` uses the existing cookie,
`X-SpeedyTapper-CSRF`, same-origin policy and confirmed public name. Native
requests may omit Origin. Maximum JSON body: 1,024 bytes:

```json
{"protocolVersion":2,"ruleset":"multiplayer-shared-arcade-v2"}
```

Response 201 contains `ticket`, integer Unix-second `expiresAt`, and
`realtimeURL`. The opaque ticket has 256 random bits, is digest-stored, single-use
and valid at most 60 seconds, bound to the exact player/session/protocol. The
service URL must use WSS except explicit loopback development. Tickets never
appear in URLs, logs or persistent client storage.

### Service-only bridge

These endpoints accept `Authorization: Bearer <service secret>`, not cookie/CSRF
authentication. Authentication precedes body decoding. All requests include the
exact capabilities above; unexpected fields are rejected and responses are
`Cache-Control: no-store`. The service secret never enters iOS.

| POST path | Other body fields | Result |
| --- | --- | --- |
| `/api/internal/multiplayer/v2/tickets/redeem` | `ticket` | Identity/binding |
| `/api/internal/multiplayer/v2/sessions/validate` | `playerID, sessionBinding` | Refreshed public identity, original binding expiry |
| `/api/internal/multiplayer/v2/results` | Immutable aggregate envelope | Matching match ID, `state:stored_unranked`, `rankingEligible:false`, duplicate flag |

Redeem/validate bodies are at most 1,024 bytes; result bodies at most 16,384 bytes.
Identity contains `playerID, name, petID, sessionBinding, expiresAt,
protocolVersion, ruleset`. Pet is nullable. The opaque binding is not a PHP
session ID/digest; it expires within an hour and no later than its source session.
Validation does not extend it. The deployed build-26 PHP compatibility update keeps at most twelve
bindings per primary session by retiring the oldest binding after a valid fresh
ticket redemption, instead of locking a valid login out after twelve reconnects.
Invalid, replayed or expired tickets cannot evict a binding.

Vapor validates every 15 seconds and authenticates a fresh ticket before resume.
Logout/rotation/deletion revocation is bounded polling, not instantaneous push.
On failed validation, stop the affected seat rather than retaining stale authority.
Full-host TLS/Authorization forwarding was verified. Genuine player revocation
and end-to-end device acceptance remain separate gates.

### Socket directory and live play

The native socket actor uses shared `MP2ClientMessage`/`MP2ServerMessage` Codable
DTOs; see [Server/README.md](../Server/README.md) for exact encoding and message
limits. Hello authenticates before actions. List/create/join, Ready and Start
belong only to the socket authority; PHP does not provide a competing live lobby.

The creator starts a full connected/Ready room. Ready includes a monotonic
intent ID and roster revision; duplicate Start returns the same countdown.
Membership changes invalidate countdowns. Fresh authentication precedes a
room/player-bound resume credential and generation rotation. Old connection/input
generations cannot act for a resumed seat.

Inputs contain identity/target/contact evidence, never client-authored score or
life totals. The pure Swift room engine derives state. Local prediction is
presentation only and reconciles against receipts/snapshots. No v1 peer
transcripts, seals, roster handshakes or unanimous submissions are sent.

### Released revision-1/2 unranked aggregate intake

The service journals immutable match ID, capabilities, duration,
`rankingEligible:false`, and 2–4 distinct player UUID/stable-seat aggregates:
score, lives, hits, misses, dodges, reaction total and nullable fastest reaction.
No names, pets, credentials, wallet or achievement claims enter that envelope.
Revision-2 hearts can restore lives, so cumulative misses may exceed three;
PHP migration 024 widens their storage and accepts 0–1,000 while current lives
remain 0–3. Deploy that additive compatibility change before revision-2 rooms.

PHP validates bounded integer fields and stores normalized aggregates plus a
payload digest atomically. Same normalized match payload is idempotent;
conflicting content under that match ID is 409. Missing/deleted players are 409
and are never recreated by delayed delivery. Account deletion removes the shared
alpha aggregate. The service archives its durable outbox file only after a
matching `stored_unranked` acknowledgement.

These are **service-reported, unranked aggregates**, not independent PHP replay
proof, human verification or a new ranked season. No v1 result/rank, progression,
coin, achievement or Game Center publication writes occur. No public v2 result
read is implemented. Railway EU runtime and PHP bridge/migration 024 were directly
verified for build 26; complete real-account result delivery remains a device-QA gate.

## Historical v1 compatibility — read-only in the new client

The uploaded build 24 uses `multiplayer-own-color-v1`, protocol/proof 1,
build `20260729-1`, GameKit live traffic and PHP peer settlement. Those backend
routes/data are not deleted by this client rewrite.

The released build-28 client retains only `GET /api/mobile/v1/multiplayer/leaderboard` for
historical top/context reads. Accepted entries require
`verification:"peer_consistent_v1"`; they are never relabeled v2 or merged with
unranked alpha aggregates. Historical Game Center best-score publication remains
separate. V1 create/join/readiness/GameKit roster/start/submission/settlement
mutation clients and live wire are removed from the released v2 client.
The full old contract is recoverable from Git history, including audit baseline
`df16cb8ef43adf3752023d12329384c2e0a08eaa`.
