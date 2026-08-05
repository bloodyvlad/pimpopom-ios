# Security policy

Report vulnerabilities privately to the repository owner. Do not publish
credentials, personal data, production exploit steps, StoreKit payloads, sessions,
identity proof, Game Center tuples, or replay/moderation evidence. Add a public
security contact before production release.

## Boundaries

- PHP is authoritative for identity, profile, ranked attempts/replay/results,
  Multiplayer settlement, moderation, achievements, account coins, catalogs,
  ownership, and idempotency. Apple-signed StoreKit state proves payment/refund;
  PHP owns its account-ledger projection.
- Validate Apple/Google proof server-side for issuer, audience, nonce/state, expiry,
  intent, and link policy. Never merge from email, nickname, device, or Game Center.
- Game Center is secondary: verify certificate/signature, bundle, signed team ID,
  salt/timestamp, challenge, persistence, uniqueness, and replay. Do not assume the
  ordinary Apple signature covers a separately supplied game player ID.
- Multiplayer trust is protocol-verified peer consistency, not server-authoritative
  play or collusion resistance. Freeze sender/seat maps and require exact evidence.
- Verify StoreKit JWS/server notifications, bind with `appAccountToken`, and key
  credit/refund/reversal idempotently by immutable transaction identity.
- Use HTTPS/platform trust, secure cookies plus CSRF, bounded requests/rates/retries,
  environment separation, and redacted logs.
- Never commit or log `.p8` keys, signing material, OAuth secrets, ad secrets,
  sessions, raw provider/Game Center IDs, StoreKit JWS, or proof bodies.

Pin Swift Package Manager dependencies, review licences/privacy manifests, minimize
SDKs, and run focused compatibility plus physical-device tests for security updates.
