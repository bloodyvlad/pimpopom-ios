# Security policy

## Reporting

Report suspected vulnerabilities privately to the repository owner. Do not open a public issue containing credentials, personal data, exploit steps against production, StoreKit transaction data, session tokens, attestation material, or moderation evidence. A dedicated security contact must be added before public release.

## Security boundaries

- The server is authoritative for identity, nickname confirmation, ranked attempts, proof replay, leaderboard state, achievements, account-bound coin balances/credits, ownership, moderation, and idempotency. Apple-signed StoreKit state is authoritative evidence of payment, entitlement, refund, or revocation; the app/server verifies it and the server owns the account-ledger projection.
- Store secrets in the deployment secret manager or Keychain as appropriate. Never place App Store `.p8` keys, signing certificates, OAuth secrets, ad credentials, raw identity tokens, or production API tokens in Git.
- Use HTTPS, certificate trust provided by the platform, short-lived revocable sessions, explicit environment separation, request size/rate limits, and redacted logs.
- Validate Apple and Google identity tokens on the server for the correct audience, issuer, nonce/state, expiry, and account-linking policy.
- Verify StoreKit signed transactions on the server, key credits by immutable transaction ID, and process server notifications/refunds idempotently.
- App Attest can raise the cost of modified-client abuse but cannot prove a human played or make automation impossible. Unsupported and recovery paths must be explicit.
- Never log raw tokens, email addresses, private relay addresses, full purchase payloads, attestation objects, or replayable proof bodies.

## Dependency policy

Prefer Apple frameworks and Swift Package Manager. Pin reviewed dependency versions through `Package.resolved`, inspect privacy manifests and licences, minimize SDK count, and remove unused SDKs. Security updates require focused compatibility and device testing before release.
