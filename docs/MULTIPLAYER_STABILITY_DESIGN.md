# Own Color Multiplayer stability design

Status: implemented in the `1.02 (23)` source candidate; physical acceptance open.

## Product rule

Own Color must feel local even when canonical GameKit traffic is late. A contact is
shown on the next display frame. Score, lives, streak, transcript, and settlement
change only after deterministic reconciliation.

| Network state | Presentation | Input | Outcome |
| --- | --- | --- | --- |
| Healthy or delayed below 1 second | No notice | Interactive | Retry/reconcile in the background |
| Delayed 1–15 seconds | Small `Catching up` HUD | Interactive for each eligible visible activation | Apply late canonical work once |
| Actual disconnect or app interruption | `Reconnecting` | Logical clock paused | Reconnect, replay controls, then snapshot |
| Still unresolved at 15 seconds | Clear failure | Disabled while ending | Cancel without settlement |
| Invalid or contradictory protocol data | Immediate integrity failure | Disabled | Cancel without settlement |

There is no centered or tilted `SYNCING` overlay. The constants are fixed at
`1_000 ms` before visible catch-up and `15_000 ms` before cancellation; neither is
an intentional input delay.

## Lobby and Start

- Ready responds locally whenever the participant exists and no mutation is in
  flight. A Ready intent waits for unanimous live-wire compatibility, then flushes
  once.
- Start requires the exact PHP/GameKit roster, all PHP participants ready, a usable
  clock, and no disconnected peer.
- Four completed clock replies establish offset. Loss, late replies, and reorder
  remain diagnostics and do not reject an otherwise compatible room.
- A failed physical Start send leaves the room waiting and retries with a fresh
  future clock. Gameplay output cannot overtake Start on the reliable lane.
- Final policy/measurement arrival retriggers roster confirmation immediately.

## Live recovery

- GameKit unreliable packets carry low-latency input/seal previews. Reliable lanes
  carry evidence, resolutions, canonical events, snapshots, and controls.
- Cumulative seals and recipient-specific journals repair ordinary loss. A later
  retry ACK clears only that recipient and exact retained control attempt.
- Start, pause, Resume, Finish, and terminal cancel remain replayable across
  reconnect. Pause holds the shared logical clock until Resume has been physically
  accepted for every intended peer. Exact Resume ACK retries then continue without
  blocking play or starting a second recovery window.
- If plan/canonical output cannot be sent, the coordinator freezes logical progress
  before an unseen target can expire. Existing eligible input remains responsive;
  recovery becomes visible only after one second.
- Snapshot chunks are bounded and complete before apply. Their canonical prefix
  must match local history and their control watermark cannot rewind newer plan or
  pause state.
- Missing resolutions, canonical ranges, snapshot tails, and future Finish packets
  request snapshots repeatedly. Protocol contradictions never enter retry loops.
- Terminal evidence and Finish delivery share one 15-second live deadline. No
  participant submits until required evidence and exact Finish delivery agree.

GameKit delegate callbacks are copied into a match-generation relay and delivered
on `MainActor`. Callbacks, PHP responses, and matchmaking completions from an old
generation are discarded.

## Transport boundary

GameKit remains the only shipping live transport. PHP receives no live taps. The
app does not claim or force a local Wi-Fi route because GameKit exposes no supported
route-selection API. A separate Bonjour/Network.framework or regional QUIC path
would require its own authenticated protocol, relay/discovery operations, privacy
review, and compatibility version.

## Acceptance still open

Before calling this physically accepted or production-ready, test real 2-, 3-, and
4-device matches on same and different networks, background/foreground, reconnect,
network transitions, rapid taps, and natural settlement. Measure next-frame local
feedback on 60 Hz and 120 Hz iPhones. Simulator gates do not replace those tests.
