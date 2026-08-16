# Own Color Multiplayer stability design

Status: approved design, not yet implemented
Date: 2026-08-16

## Goal

Keep build 22's immediate local tap response while restoring build 20's lobby and
match stability. Ordinary packet delay must not disable input, cover the board, or
end a match. PHP and the Multiplayer v1 settlement tuple remain unchanged.

## Confirmed failures

- The build 22 TestFlight crash is an actor-isolation trap. GameKit invoked
  `GKMatchDelegate.match(_:didReceive:fromRemotePlayer:)` off the main thread while
  `LiveMultiplayerGameKitClient` was `@MainActor`.
- Ready is blocked behind the full GameKit roster, compatibility, four-sample clock,
  network-policy vote, and PHP confirmation sequence. A final policy vote can also
  wait for the next 1.25-second lobby poll before confirmation is retried.
- Four completed probes are treated as a 3% loss/reorder sample. One missing or
  in-flight probe is at least 20% loss and one reordered probe is 25%, so the gate
  effectively requires a perfect startup sample.
- The live coordinator declares recovery after 40–100 ms and cancels after
  120–250 ms. One unresolved local input cancels after 240–500 ms. Terminal drain
  uses the same short budget. These paths stop the frame scheduler and go directly
  to results.

## Product behavior

Own Color input is locally predicted and remains interactive while canonical
evidence catches up. Canonical score, lives, streak, transcript, and settlement
remain deterministic and are never fabricated.

| Condition | Presentation | Input | Recovery |
| --- | --- | --- | --- |
| Evidence/frontier delay below 1 second | No notice | Interactive | Cumulative seals and reliable journal retry |
| Delay from 1 to 15 seconds | Small nonblocking `Catching up` HUD status; no centered stamp or overlay | Interactive for every presented eligible activation | Reliable checkpoint and periodic snapshot request |
| Recovered before 15 seconds | Remove status without interrupting play | Interactive | Apply late canonical result and reconcile prediction once |
| Actual GameKit disconnect | Explicit nonblocking `Reconnecting` state and coordinated pause | Paused because evidence cannot be transmitted safely | Reinvite/reconnect and snapshot, with 15-second grace |
| Unresolved gap or disconnect at 15 seconds | Explain that the connection could not recover, then end without settlement | Disabled only when ending | Deterministic terminal cancellation |
| Conflicting or invalid protocol evidence | Immediate integrity failure | Disabled | Cancel without settlement |

Recovery never uses the current centered, tilted `SYNCING` stamp. A packet gap does
not select `.syncing` input mode. The display link continues, preannounced
activations still render, and eligible taps are captured. The coordinator still
holds canonical publication behind incomplete evidence, so no rollback or false
settlement is introduced. A long gap may exhaust already announced activations;
the client must not invent later canonical targets.

The constants are fixed for this compatibility version:

- invisible recovery window: `1_000 ms`;
- hard recovery and terminal-drain window: `15_000 ms`.

They are health thresholds, not intentional input delay. Clean-path tap handling
does not wait for either threshold.

## Lobby and Ready

1. A local Ready tap responds immediately whenever the current participant exists
   and no readiness mutation is already pending.
2. If the GameKit roster is not complete, retain a local Ready intent. Do not send
   that intent to PHP until every peer confirms the new live-wire version and exact
   capability set. This preserves mixed-build fail-before-start safety.
3. When compatibility becomes unanimous, flush the retained intent idempotently.
4. Start remains gated on exact GameKit/PHP roster agreement, all PHP participants
   ready, a usable coordinator clock, and no disconnected peer.
5. Four completed clock replies establish offset. Attempted, lost, late, and
   reordered probes are diagnostic data, not a Ready or Start rejection rule.
6. Receiving the measurement or final policy vote directly retries roster
   confirmation; it never waits for the next PHP poll.
7. Timeout before four completed replies produces a clear retryable connection
   error. It does not silently leave the button disabled.

The corrected behavior advertises a new live-wire version/capability. Builds using
the harsh build 22 policy must fail before gameplay rather than enter a mixed match.

## GameKit callback safety

- Treat GameKit delegate entry points as nonisolated callbacks.
- Copy the callback payload and player ID, then enqueue delivery onto `MainActor`.
- Associate every matchmaking attempt and accepted `GKMatch` with a monotonically
  increasing generation. Deliver an event only when its match and generation are
  still active.
- Invalidate the generation before clearing the delegate or disconnecting so
  already queued callbacks become harmless.
- Recheck the match generation after every asynchronous lobby/PHP confirmation
  boundary before mutating presentation state.

This addresses the symbolicated build 22 crash and the adjacent stale-callback
risk without assuming GameKit delivers delegates on a particular queue.

## Transport and reconciliation

- Keep `GKMatch`, immediate local prediction, the unreliable fast-input/seal lane,
  and reliable evidence/canonical/control lanes.
- A missing unreliable message is expected. Later cumulative seals and the reliable
  journal heal it; absence alone is never an integrity failure.
- Preserve input IDs, lane-specific sequencing, deduplication, acknowledgements,
  evidence journals, snapshots, and PHP transcript rules.
- Start recovery work immediately, but keep it invisible until one second.
- Request snapshots idempotently while the gap persists. Do not reopen a consumed
  activation or charge a second miss during reconciliation.
- Use the same 15-second ceiling for frontier, input-resolution, disconnect, and
  terminal-drain recovery. Protocol contradiction remains the only immediate
  cancellation reason.
- Add privacy-safe TestFlight logging for phase/generation, reason-coded recovery,
  connection changes, gap age, snapshot attempts, and terminal reason. Never log
  player IDs, names, match IDs, tokens, or transcripts.

## Local-network routing

GameKit remains the only shipping transport in this change. Apple describes
`GKMatch` as peer-to-peer and documents GameKit support for both local and Internet
game communication, but it exposes no supported API that reports or forces the
route selected for a particular match. The app therefore must not claim two phones
are on the same LAN from `NWPath` merely because both use Wi-Fi.

A separate local route would require Bonjour/Network.framework discovery, a Local
Network permission prompt, authenticated mapping to the GameKit roster, duplicate
suppression across two transports, lifecycle recovery, and Internet fallback.
Multipeer Connectivity is nearby-only and its discovery APIs are deprecated on the
current SDK. This is not part of the stability fix.

If post-fix telemetry still shows transport-level problems, evaluate a separate
prototype in this order:

1. Bonjour plus Network.framework as an optional authenticated LAN fast path;
2. Network.framework QUIC to a regional relay for controlled Internet routing;
3. Valve GameNetworkingSockets only if cross-platform P2P justifies custom
   signaling, STUN/TURN, C++ packaging, and relay operations.

## Verification

Automated tests must prove:

- a GameKit callback arriving from a detached/background executor is delivered on
  `MainActor` without a trap;
- callbacks from an invalidated match generation are discarded;
- Ready intent is immediate, retained before compatibility, flushed once, and
  cleared on leave/retry;
- one lost, in-flight, late, or reordered clock reply does not reject startup;
- the final policy vote immediately retriggers roster confirmation;
- packet duplication, reorder, and delays from 0 through 800 ms never disable
  input, show recovery UI, or terminate the match;
- a gap from 1 through 15 seconds shows only the nonblocking HUD state and recovers;
- a real disconnect can reconnect inside 15 seconds and rejects stale callbacks;
- frontier, resolution, and terminal recovery do not terminate before 15 seconds;
- contradictory evidence still cancels immediately and never settles;
- two-, three-, and four-seat deterministic virtual packet runs converge on the
  same transcript under loss, duplication, reorder, retry, and reconnect.

Before release, run the full repository check and physical 2-, 3-, and 4-device
matches covering different networks, same Wi-Fi, background/foreground, a network
transition, reconnect, natural finish, and rapid taps. Simulator success alone is
not the physical-network acceptance gate.

## Primary references

- [Apple: Exchanging data between players in real-time games](https://developer.apple.com/documentation/gamekit/exchanging-data-between-players-in-real-time-games)
- [Apple: GKMatch](https://developer.apple.com/documentation/gamekit/gkmatch)
- [Apple: NWBrowser](https://developer.apple.com/documentation/network/nwbrowser)
- [Apple: Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity)
- [Valve: GameNetworkingSockets P2P requirements](https://github.com/ValveSoftware/GameNetworkingSockets/blob/master/README_P2P.md)
