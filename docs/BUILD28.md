# Build 28 — 4×4 pickups and private-room discovery

Implemented candidate, 2026-09-11. Deployment and Apple state are separately
recorded in CURRENT_VERSION.md / RELEASE.md; this document alone proves neither.

## Gameplay and artwork

- Arcade hearts/clocks and Multiplayer hearts cannot spawn before the actual
  4×4 board. A still-active 2×2 target across 40 seconds remains ineligible.
- Existing 12–20-second opportunities, 250 ms blocked retries, three-second
  lifetimes and free-cell reservation are unchanged. An overdue opportunity may
  spawn shortly after 4×4 becomes available; there is no extra 12-second wait.
- Arcade selects `reaction-proof-v5`, proof 3. The exact event shapes are unchanged;
  pre-4×4 blocked ticks remain in the proof. Retained v3/v4 replay and trace hashes
  stay unchanged. The compatible PHP commit is `f84dc9218b58bb937326be931f2ee969abed4282`.
- Multiplayer remains gameplay revision 2 and never receives clocks. The server
  delays heart placement; older revision-2 clients can render the same events.
- Default, Disco and Light use the native `clock.arrow.circlepath`; Pixel uses
  stepped artwork. Textures are cached at theme preparation, never on contact.

## Rooms and discovery

- Each room gets a stable eight-character OS-random code from an unambiguous
  32-character alphabet. Collision checks include retained rooms. UUID remains the
  internal identity. Codes are discovery handles, not account credentials.
- Public games appear in the joinable list and case-insensitive creator-name
  substring search. Exact case-insensitive code/full UUID works for both kinds.
- Private games are excluded from public/name/prefix searches. Anyone with the
  complete code can find/join while connected, waiting, compatible and not full;
  ordinary primary login still applies. No password or invite approval.
- The waiting room displays Copy/Share controls; live and results views retain
  the code. The creation toggle explains discoverability.
- Welcome advertises `roomDiscoveryRevision:1`; the app checks it before private
  creation. An older service cannot silently create a public room for that request.
  Older clients can still create public rooms by omitting the optional flag.
- Search is debounced 250 ms, bounded to 128 UTF-8 bytes and fenced by monotonic
  request IDs plus exact query. The service pushes only the active subscription;
  full/finished/left rooms disappear promptly. Leave/reconnect starts a fresh
  request, so stale responses cannot resurrect a list or overwrite a newer query.

## Evidence and release order

The integrated four-client local WebSocket run lasted 92 seconds: 5,480 snapshots,
388 hits, 60–67 color rotations per seat, no player collisions, no decoy conflicts
in 11,208 checks, no heart on 1×1/2×2, and exactly one winner in a four-way claim.
Three guests found/joined the private room by code. These are local socket tests,
not four physical devices or measured internet latency.

Focused Simulator tests: 33 passed, zero failures/skips; all four themed hub and
waiting-room captures inspected. Final comprehensive gate and Linux verification
are recorded with the release once complete.

Required order: verify/deploy PHP v5 first, verify/deploy Railway room support,
then archive/upload build 28 to the existing Internal QA / External QA groups.
Retain PHP v4 rollback and previous Railway image. PHP rollback cannot settle v5
runs; coordinate beta availability before rollback. No migrations, resets,
account/economy changes, live ads, new regions or public App Store submission.
