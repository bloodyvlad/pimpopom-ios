# Build 24 Fast Multiplayer Design

Date: 2026-08-21

## Goal

Make Multiplayer feel immediate and remain playable under ordinary GameKit delay,
loss, duplication, and reordering. Build 24 prioritizes a working fast beta; final
anti-cheat hardening remains a later, separately reviewed change.

## Scope and boundaries

- Change only the active iOS repository. Do not modify the PHP repository.
- Keep the PHP `multiplayer-own-color-v1`, protocol 1, proof 1 transcript and
  settlement contract unchanged.
- Keep PHP authoritative for lobby readiness and Start eligibility.
- Keep local own-color touch feedback independent of peer acknowledgement.
- Permit canonical reconciliation to trail local play by as much as two seconds.
- Prepare and verify a TestFlight archive for build 24, but do not upload it
  without a separate explicit upload instruction.

## Ready synchronization

The current player's Ready button and participant card project the retained local
Ready intent immediately. The server-confirmed value replaces the projection after
the readiness PATCH succeeds; a failure rolls the projection back and presents a
localized error.

When the GameKit roster is connected, clients also send a retained reliable Ready
hint to peers so their participant cards update without waiting for the 1.25-second
PHP poll. The hint is presentation-only. Start remains disabled until the PHP match
snapshot says every participant is ready and the existing GameKit prerequisites
are satisfied. A later PHP snapshot always corrects a stale peer hint.

## Live input and sealing

Local touch capture and local prediction remain the latency-critical path. A touch
immediately hides or presses the owned target and triggers local feedback; it does
not wait for GameKit, the coordinator, another player, or PHP.

The sealed frontier must not close the millisecond currently being processed by
UIKit. Build 24 adds a 150-millisecond capture grace: periodic seals close only
through `logicalNow - 150 ms`, while preserving cumulative input-sequence evidence.
This bounds canonical delay without affecting local feedback.

A valid, monotonic input that arrives inside a recently closed time interval is an
ordinary late/reordered input, not a match-fatal contradiction. The coordinator
converts it into one immutable ignored resolution and continues the match. Inputs
that are beyond the two-second live reconciliation allowance are also ignored.
Duplicate identical evidence remains idempotent.

Only the following remain immediately fatal:

- conflicting payloads for the same `(seat, inputSequence)`;
- an invalid or unknown seat;
- impossible sequence regression or malformed protocol data;
- conflicting terminal evidence or transcript state.

Packet loss, packet reorder, late evidence within the allowance, a missing fast
preview, and one stale tap must never end the match.

## Compatibility

The changed live behavior receives a new GameKit live-wire version/capability so
Build 24 cannot enter a live match with Build 22 or Build 23. The PHP build ID and
final transcript tuple remain unchanged because PHP does not consume the live wire.

## Player-facing failure behavior

Internal Swift enum names and numeric error codes never appear in the UI. A fatal
live-wire contradiction produces a localized, stable player message and a retained
internal reason code for diagnostics. A locally cancelled match is described as
ended and unranked, not as server-held for review unless PHP actually reports the
`review` state.

## Tests and acceptance

Automated tests must cover:

- immediate Ready projection in both the button and current-player card;
- peer Ready hint application and correction by a PHP snapshot;
- rollback after a failed readiness PATCH;
- a seal emitted at logical time 250 closing only through 100;
- a touch timestamped before a recent seal being ignored without match failure;
- identical duplicates remaining idempotent and conflicting duplicates remaining
  fatal;
- loss/reorder recovery continuing play and converging on one canonical transcript;
- no raw internal error text in player-facing results.

The release gate is the repository's full `Scripts/check.sh`, `git diff --check`, a
generic-device archive, archive signature/entitlement/Info.plist inspection, and
physical TestFlight follow-up on two devices. Simulator automation cannot prove
real GameKit transport behavior, so physical 2/3/4-device acceptance remains an
explicit beta gate.
