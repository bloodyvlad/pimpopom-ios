# Current native API contract

This file describes only the deployed compatibility surface used by iOS build 20.
Server implementation and deployment remain owned by the separate PHP repository.

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

Multiplayer routes are under `/api/mobile/v1/multiplayer` and are specified below.

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

Compiled tuple: build `20260729-1`, ruleset `reaction-proof-v3`, proof version 2.

1. Bootstrap the PHP session.
2. A signed-in confirmed profile requests `/api/runs` before gameplay.
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
Multiplayer best scores and achievement completion. iOS never calls
`GKLeaderboard.submitScore` or `GKAchievement.report`.

## Multiplayer availability and lobby API

Compatibility tuple:

```text
base       /api/mobile/v1/multiplayer
build      20260729-1
mode       own_color
ruleset    multiplayer-own-color-v1
protocol   1
proof      1
players    2...4
events     <= 2,500
duration   <= 900,000 ms
```

Private routes require cookie authentication; mutations also require CSRF. Before
create/join/roster/start, the player needs a primary profile, confirmed nickname,
linked publishing-enabled Game Center identity, authenticated persistent player,
and a successful Game Center proof no older than ten minutes.

| Method and path | Request / result |
| --- | --- |
| `GET /leaderboard` | Public top five plus optional authenticated context |
| `GET /lobbies?limit=20` | Limit 1–50; public lobby summaries exclude GameKit routing group |
| `POST /matches` | `{"mode":"own_color","capacity":2,"buildId":"20260729-1"}` |
| `GET /matches/{id}` | Private member state; nonmember is `404` |
| `POST /matches/{id}/join` | `{}` |
| `POST /matches/{id}/leave` | `{}`; forming creator transfers, started leave cancels |
| `PATCH /matches/{id}/readiness` | `{"ready":true}` |
| `POST /matches/{id}/gamekit-roster` | Exact persistent GameKit roster/coordinator |
| `POST /matches/{id}/start` | `{}`; creator only after unanimous ready/roster |
| `POST /matches/{id}/submissions` | Exact manifest hash and seat-only transcript |
| `GET /matches/{id}/settlement` | Collecting, settled, or review state |

A forming lobby expires after ten minutes. PHP returns stable participant UUID,
seat, unique color, readiness, capacity, creator flag, selected pet, and a private
positive 31-bit `playerGroup`. Clients validate identifiers, unique seats/colors,
counts, state, and timestamps before adopting it.

## PHP lobby to GameKit

Use the private `playerGroup` in `GKMatchRequest` and connect exactly the PHP
participant count. Peers exchange persistent player-to-participant mappings, then
currently elect the lexicographically smallest `gamePlayerID` as fixed coordinator.
Each posts its local ID, all observed remote IDs, and the same coordinator to PHP.
PHP validates the complete set against linked lobby members and stores hashes, not
raw Game Center IDs.

Only after all roster confirmations and readiness may the creator start. The start
response binds this immutable shape:

```json
{
  "protocolVersion": 1,
  "ruleset": "multiplayer-own-color-v1",
  "proofVersion": 1,
  "matchId": "UUID",
  "buildId": "20260729-1",
  "seed": "unpadded-base64url-32-bytes",
  "startingLives": 3,
  "participants": [
    { "participantId": "UUID", "seat": 0, "colorIndex": 0 }
  ],
  "manifestHash": "unpadded-base64url-sha256"
}
```

The seed binds the manifest; it is not a specified random schedule. Live tuples
contain seats and integers, never names, pets, profile UUIDs, or Game Center IDs.

## Current GameKit live protocol

PHP is not a live relay. One versioned `GKMatch` envelope carries roster, clock,
future plan/cancel, input, canonical event batch, acknowledgement, snapshot,
pause/resume, start, and finish packets. Build 20 sends every envelope with
`GKMatch.SendDataMode.reliable`.

The fixed sender map is frozen after roster confirmation. Inputs are broadcast to
all peers and witnessed against sender/seat before an input-derived tuple is
accepted. The coordinator converts touch time, sorts `(inputAt, seat, inputSequence)`,
and commits only through `coordinatorNow - 250 ms`. `handledAt` is delay evidence;
it cannot move canonical logical time beyond the watermark.

Peers acknowledge contiguous canonical sequences and request snapshots after gaps.
Snapshots carry reducer state, pending plans, and the shared clock anchor. Historical
catch-up is silent. A bounded disconnect pauses logical time; v1 does not migrate
coordinator authority. Unrecoverable stream or evidence cancels/withholds.

This reliable, 250 ms path is the current contract and latency source. The approved
FAST design must use new per-lane sequencing and explicitly version any changed
evidence/tuple meaning; it cannot reinterpret v1 in place.

## Exact Multiplayer transcript

Every participant submits the same `manifestHash` and:

```json
{
  "matchId": "UUID",
  "buildId": "20260729-1",
  "ruleset": "multiplayer-own-color-v1",
  "protocolVersion": 1,
  "proofVersion": 1,
  "events": []
}
```

All members are integers. `seq` begins at 1 and is contiguous; logical time is
nondecreasing. Hit/miss order uses `inputAt`; `handledAt` remains separate.

| Event | Tuple |
| --- | --- |
| Target | `[0, seq, at, ownerSeat, targetId, cell, colorIndex]` |
| Hit | `[1, seq, inputAt, handledAt, seat, targetId, cell]` |
| Miss | `[2, seq, inputAt, handledAt, seat, reason, cell]` |
| Decoy activate | `[3, seq, at, ownerSeat, decoyId, cell, colorIndex, lifetimeMs]` |
| Decoy expire | `[4, seq, at, decoyId]` |
| Player out | `[5, seq, at, seat]` |
| Finish | `[6, seq, at]` |

Miss reasons: 0 empty, 1 wrong, 2 late. Late expiry may use cell `-1`; board cells
are 0–15. Replay enforces the gameplay rules in `GAMEPLAY_SPEC.md`, including fair
ownership rotation, response/schedule bounds, decoys, lives/recovery, score, streak,
finish, and placement.

## Settlement and ranking

Before all submissions, state is `collecting` and never leaderboard-eligible. The
client retains the exact submission for idempotent retry and polls settlement. A
clean final response is `settled`, `leaderboardEligible: true`, verification
`peer_consistent_v1`, and a derived result for every participant. A mismatch is
review/withheld. A missing peer may remain collecting; do not fabricate completion.

Each accepted participant result is an immutable row. Public reads use the usual
top-five/context shape. PHP order is score, placement, duration, hits, achieved
time, then result ID. PHP publishes only each player's personal best to Game Center
vendor ID `com.otcsoftware.pimpopom.multiplayer.verified`.

Matching peer submissions prevent one lone coordinator from silently rewriting a
match. Colluding or modified clients can still manufacture matching plausible
evidence; describe results only as protocol-verified and peer-consistent.
