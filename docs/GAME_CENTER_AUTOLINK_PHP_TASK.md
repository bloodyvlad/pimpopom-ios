# PHP task — make the current signed-in profile own the active Game Center player

Status: backend-only implementation task. Apply, review, test, and deploy this work from the parent PHP repository. The PimPoPom iOS repository must not modify or deploy the PHP service.

## Objective

When iOS has both:

- an authenticated PimPoPom PHP session; and
- an authenticated `GKLocalPlayer` with persistent `teamPlayerID` and `gamePlayerID`,

the app automatically requests a one-use challenge and submits a fresh GameKit proof with `publish: true`. Make that request idempotently bind the current Game Center player to the **currently signed-in PimPoPom profile**, even when either scoped ID was previously associated with another internal profile.

This is a deliberate **current-profile-wins** policy for Game Center only. It does not merge PimPoPom profiles, identities, wallets, purchases, results, cosmetics, or achievements.

PHP remains the only publisher of protocol-verified Arcade personal bests and authoritative achievement unlocks. The client must never submit a score or achievement directly to Game Center.

## API behavior

Retain the existing routes and proof body:

```http
POST /api/profile/game-center/challenge
{}
```

```http
POST /api/profile/game-center
{
  "challengeId": "...",
  "teamPlayerId": "...",
  "gamePlayerId": "...",
  "publish": true,
  "publicKeyUrl": "https://static.gc.apple.com/public-key/...cer",
  "signature": "BASE64",
  "salt": "BASE64",
  "timestamp": 1234567890123
}
```

Required changes:

1. Both routes still require an authenticated PimPoPom session and valid CSRF protection.
2. Remove the **recent Google/Apple reauthentication** requirement only from these two Game Center routes. Do not weaken recent-authentication requirements for primary-provider linking, account deletion, StoreKit binding, or other sensitive routes.
3. Continue to require a fresh, session-bound, single-use challenge before accepting GameKit material.
4. Continue to verify Apple's certificate chain, bundle ID, signed `teamPlayerID`, timestamp, salt, challenge freshness, and assertion replay protection.
5. Continue to treat `gamePlayerID` as an accompanying client assertion, not as a field covered by Apple's ordinary non-Apple-Arcade signature.
6. With a valid proof and `publish: true`, atomically make the submitted team/game pair belong to the current PHP profile. Existing ownership by another profile is no longer a `409` conflict.
7. Repeating the same current-profile/same-team/same-game request is idempotent. It may refresh `last_verified_at`, keep publication enabled, and reconcile missing desired work, but it must not erase a successfully delivered outbox merely because the app foregrounded again.
8. Preserve the existing response shape. Additive diagnostic booleans such as `reassigned` are allowed, but never return raw scoped player IDs.

Authentication cancellation, parental restrictions, Game Center unavailability, network failure, and PHP failure remain nonfatal to gameplay and all non-Game-Center account/economy features.

## Atomic reassignment

Implement reassignment in the identity/publication service, not in the HTTP controller. Retain the database uniqueness constraints on:

- one `player_game_center_bindings` row per PimPoPom player;
- unique `team_player_id_hash`; and
- unique `game_player_id_hash`.

Use this transaction/lock model:

1. Fully validate the request, challenge, certificate chain, signature, timestamp, bundle, persistent-ID shape, and replay material before changing ownership.
2. Domain-hash the team and game scoped IDs using the existing schemes. Prepare a **new** AES-256-GCM encryption of `gamePlayerID` for the final player/team association; do not move ciphertext encrypted with another player's associated data.
3. Discover the current profile plus the preliminary owners of:
   - the submitted team hash;
   - the submitted game hash; and
   - any different Game Center binding already attached to the current profile.
4. Acquire the existing per-player Game Center publication advisory lock for every affected PimPoPom UUID in lexicographically sorted order. Release in reverse order. This must serialize reassignment with the worker, publication disable, moderation, and account deletion.
5. Begin one database transaction and re-query all relevant bindings and outbox rows with `FOR UPDATE`.
6. If the locked affected-player set is incomplete because ownership changed after preliminary discovery, roll back, release, and retry discovery with the expanded sorted set. Use a small bounded retry count and fail transiently rather than mutating without every required publication lock.
7. If the exact team/game pair already belongs to the current profile, take the idempotent path: refresh verification/publication timestamps as needed and run the normal authoritative backfill without destructively resetting delivered state.
8. Otherwise:
   - remove the Game Center binding rows of every displaced owner of the submitted team or game hash;
   - remove any different Game Center binding currently attached to the current profile;
   - update or recreate the current profile's binding with the submitted hashes, newly encrypted game ID, current link/verification timestamps, publication enabled, and publication disabled cleared;
   - do not transfer the current profile's former pair to a displaced profile or infer a reverse association.
9. In the same transaction, revision-cancel every outbox row whose Apple destination or owning profile changed. For those affected rows:
   - set `desired_value = NULL`;
   - set `delivered_value = NULL`;
   - increment `desired_revision`;
   - set `state = 'cancelled'`;
   - reset `attempt_count = 0`;
   - set a fresh `available_at`/`updated_at`;
   - clear `lock_token`, `locked_at`, `apple_submission_id`, `delivered_at`, `last_http_status`, `last_error_code`, and `last_error`.
10. Backfill the current profile's authoritative verified Arcade best and all allowlisted unlocked achievements only after the new binding is in place. This creates or reactivates the correct prerelease/production-lane desired rows.
11. Commit, then release every advisory lock.

Do not delete or rewrite any PimPoPom score, achievement, wallet, purchase, entitlement, pet, theme, provider identity, or primary session record during this operation.

## Apple history limitation

Apple exposes no supported per-player operation that lets this service remove a previously delivered leaderboard score or achievement from the displaced Game Center account. Reassignment therefore:

- stops future delivery to the old destination;
- publishes the current profile's authoritative state to the newly active destination; and
- does **not** promise to erase Game Center history that Apple already accepted for a prior destination.

Document this as a platform limitation. Do not submit zero, fabricated values, or client-authored correction claims.

## Concurrency and outbox invariants

- Keep the existing worker rule: after leasing and while holding the player's advisory lock, re-read binding and authoritative PHP state immediately before the Apple request.
- A stale worker lease must fail its revision/token check after reassignment and must not acknowledge, retry, or overwrite the new destination.
- Keep prerelease and production lanes separate.
- Keep outbox uniqueness by player, publication kind, Apple vendor ID, and lane.
- A no-change idempotent auto-link must not turn a succeeded row back into pending.
- A real destination change must clear prior delivery evidence before authoritative backfill so the new Apple destination receives the current state.
- Never hold publication locks in nondeterministic order.

## Security and privacy requirements

- Game Center remains a secondary, link-only identity. It cannot create or authenticate a PimPoPom profile, recover a wallet, authorize StoreKit value, or bypass a primary PHP session.
- Retain session authentication, CSRF, rate limits, challenge expiry, assertion replay prevention, Apple certificate validation, HTTPS public-key restrictions, bundle validation, timestamp tolerance, and strict request-field validation.
- Store only domain-separated hashes plus the existing authenticated encryption required for outbound `gamePlayerID`. Never persist or log raw team/game IDs, proofs, public-key query strings, cookies, CSRF values, Apple credentials, nicknames, or email addresses.
- Do not reveal the prior owning PimPoPom UUID in success or error responses.
- Keep all score, achievement, moderation, and eligibility decisions server-authoritative.
- Record the residual platform trust boundary explicitly: Apple's ordinary GameKit identity signature authenticates `teamPlayerID` but not the accompanying `gamePlayerID`. Current-profile-wins reassignment of both values therefore accepts the existing client assertion for that association; uniqueness, encryption, and a valid team proof do not make the pair cryptographically verified. Do not describe it as stronger than it is.

## Required tests

Add MariaDB-backed service/API tests for at least:

1. authenticated first link with persistent team/game IDs;
2. identical repeated link is idempotent and preserves succeeded delivery state;
3. current profile takes a team/game pair from one prior profile;
4. current profile replaces its own old pair;
5. team and game hashes initially owned by different profiles;
6. reassignment re-encrypts the game ID for the new player/team associated data;
7. displaced and current outboxes are revision-cancelled and every delivery/lease/error field listed above is cleared;
8. authoritative best/achievement backfill targets only the current profile after reassignment;
9. a processing worker cannot publish to the old destination after reassignment begins;
10. two concurrent opposite reassignment attempts cannot deadlock or violate uniqueness;
11. ownership changes between discovery and row locking trigger the bounded retry path;
12. a long-lived but authenticated PHP session can obtain a challenge and link without recent primary reauthentication;
13. signed-out, invalid-CSRF, expired challenge, stale timestamp, invalid certificate/signature, wrong bundle, transient IDs, malformed Base64, replayed assertion, and missing `publish: true` requests still fail;
14. no route allows Game Center-only login/registration or access to another profile's wallet/economy;
15. account deletion, publication worker, moderation, and reassignment preserve their shared publication-lock ordering.

Retain existing score/achievement publication and held-job recovery tests. Update prior conflict tests to assert current-profile-wins reassignment instead of `409`.

## Documentation and deployment

- Record a new accepted PHP decision that explicitly supersedes the one-to-one conflict/refusal and explicit-connect-consent portions of the prior Game Center decisions. Keep the no-profile-merge and server-authority rules.
- Update the PHP API/backend documentation to describe automatic authenticated linking and the Apple-history limitation.
- Run the complete PHP/Node/MariaDB test gate, migration checks, and `git diff --check`.
- Deploy only from a clean reviewed PHP `main` commit through the normal Hostinger artifact/migration process.
- After deployment, smoke:
  1. signed-out rejection;
  2. authenticated challenge/proof;
  3. same-pair idempotency;
  4. controlled reassignment between test profiles;
  5. current-profile backfill;
  6. stale outbox cancellation; and
  7. Apple prerelease delivery/propagation.

Do not claim Game Center synchronization complete until App Store Connect shows the current player's Arcade entry and eligible achievements after PHP accepts and dispatches the new outbox state.
