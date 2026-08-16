# FAST Multiplayer implementation and acceptance

Status: implemented in the `1.02 (23)` source candidate; not uploaded.

## Shipping scope

- Mode remains 2–4-player `own_color` with one fixed coordinator.
- PHP contract remains build `20260729-1`, ruleset
  `multiplayer-own-color-v1`, protocol 1, proof 1, maximum 2,500 events and
  900,000 logical milliseconds.
- Local contact feedback appears on the next display frame. Prediction never edits
  canonical score, lives, streak, or transcript.
- GameKit live wire v3 rejects mixed capability sets before Start.
- Fast input is unreliable by design. Evidence, resolution, canonical, snapshot,
  Start/pause/resume/Finish/cancel recovery is reliable and recipient-specific.
- Recovery is silent below 1 second, nonblocking `Catching up` from 1–15 seconds,
  and cancellation occurs only at the bounded deadline or on a protocol
  contradiction.
- A real disconnect pauses shared logical time. Resume becomes authoritative only
  after its reliable send is physically accepted for every intended peer; its
  exact-ACK journal continues retrying in the background.
- Snapshot assembly is bounded, chunk-complete, prefix-consistent, and causally
  prevented from restoring stale plan/pause metadata.
- Single- and Multiplayer hit fly-outs share the same straight, borderless,
  points-plus-rating glow. HUD-to-board layout spacing is exactly 5 points.

## Automated release gate

`Scripts/check.sh` plus `git diff --check` must pass from the exact clean source.
Coverage includes:

- detached/stale GameKit callback isolation and matchmaking generations;
- immediate retained Ready intent and immediate final-policy confirmation;
- delayed/lost/reordered clock diagnostics without startup rejection;
- multi-activation local prediction with exactly one disposition per InputID;
- 1-second notice and 15-second frontier, resolution, reliable, disconnect, and
  terminal recovery boundaries;
- recipient-specific ACK/retry behavior for 2-, 3-, and 4-seat journals;
- physical Start ordering, exact Pause delivery, and all-recipient physical Resume
  output barriers;
- duplicate Start idempotence after clock adjustment;
- canonical gap, partial snapshot, overlapping prefix, stale metadata, and future
  Finish recovery;
- transcript equality and deterministic reducer order across the supported matrix;
- catch-up input interactivity, four-theme fly-outs, five-point layout spacing, and
  all-theme back-button taps on the named iPhone 17 Simulator.

## Physical/TestFlight acceptance

Run distinct Game Center accounts and devices for 2-, 3-, and 4-player matches:

1. same Wi-Fi, different networks, and a Wi-Fi/cellular transition;
2. 0–800 ms jitter, ordinary loss/reorder/duplicates, background/foreground, and
   reconnect inside 15 seconds;
3. rapid and simultaneous taps, natural player-out/Finish, identical transcripts,
   settlement, and leaderboard visibility;
4. 60 Hz and 120 Hz contact-to-local-feedback measurements, with p95 at or below
   33 ms and no artificial canonical wait on the touch path;
5. no crash, centered Syncing overlay, unseen-target penalty, orphaned evidence,
   double penalty, premature cancellation, or stale callback/state resurrection.

Record device, OS, refresh rate, network profile, exact commit/build, result, and
artifact location. These physical gates are open until evidence is recorded.

## Deferred work

Custom LAN routing, regional QUIC relay, coordinator migration/best-host election,
and concurrent per-seat targets are not part of build 23 and require separately
versioned design and backend/operations review.
