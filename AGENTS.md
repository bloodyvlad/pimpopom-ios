# PimPoPom repository instructions

These rules apply to every task in this native iOS repository. A specific user
instruction takes precedence.

## Start safely

1. Run `git status --short` and `git rev-parse --show-toplevel` before editing.
2. Read the relevant parts of `README.md`, `docs/CURRENT_VERSION.md`, and
   `docs/DECISIONS.md`.
3. Read the domain contract for gameplay, API, monetization/privacy, testing, or
   release work.
4. For visual work, inspect `docs/DESIGN_QA.md`; it is evidence, not release truth.
5. For asset work, read the matching `assets/**/SOURCES.md` and retain provenance,
   licences, editable/lossless masters, hashes, and rollback sources.

This checkout may be a linked worktree or sit near another repository.

- Never edit, restore, stage, commit, reset, stash, clean, or deploy the parent
  PHP/web repository as part of an iOS task.
- Run Git commands from the confirmed PimPoPom top level.
- Preserve unexplained changes. Stop if intended edits overlap them.
- Use one editing task per checkout. Use separate `codex/<task>` worktrees for
  parallel implementation.
- Never commit signing keys, profiles, OAuth secrets, App Store keys, ad secrets,
  session tokens, or production credentials.

## Sources of truth

| Concern | Source |
| --- | --- |
| Code and resources | Exact PimPoPom Git commit |
| Current release/status | `docs/CURRENT_VERSION.md` and `docs/RELEASE.md` |
| Binding choices | `docs/DECISIONS.md` |
| Gameplay | `docs/GAMEPLAY_SPEC.md` plus deterministic core tests |
| Backend compatibility | Deployed server implementation plus `docs/API_CONTRACT.md` tests |
| Paid value | App Store-signed state plus the server ledger |
| Test evidence | `docs/TESTING.md` and named artifacts/devices |
| Visual evidence | `docs/DESIGN_QA.md` and referenced captures |
| Asset rights | Matching `assets/**/SOURCES.md` |

Do not describe a task as shipped, a Simulator run as device validation, a
TestFlight build as production, or a protocol-verified result as human-verified.

## Architecture boundaries

`Packages/PimPoPomCore` and the separate `Server/` Vapor service are Swift packages.
`Design`, `Features`, `Gameplay`, and `Services` are app-target folders:

- `PimPoPomCore`: deterministic configuration, state, scoring, timers, seeded
  test randomness, Multiplayer v2 protocol/room engine, and Arcade proof events.
  No Apple UI, network, storage, audio, ads, or StoreKit imports.
- `Server/`: authenticated socket room authority and off-path durable result
  outbox. Share pure rules; never move PHP identity/economy authority here.
- `App/Gameplay`: SpriteKit rendering, first-presentation timing, touch bridge,
  and local game coordination. It must not duplicate rules.
- `App/Features`: SwiftUI screens and feature coordinators. It must not invent
  backend authority.
- `App/Services`: typed HTTP, Apple/Google identity, Game Center, GameKit,
  StoreKit, ads/consent, audio, preferences, and lifecycle adapters.
- `App/Design`: theme, cell, pet, typography, spacing, and reusable visuals.
- `PimPoPomApp`/`RootView`: composition and navigation.

Keep UI/SpriteKit work on the main actor, isolate mutable service state, make
cancellation explicit, and keep network, disk, decoding, ads, and purchases off
the reaction path.

## Product invariants

- Arcade, Zen, and Multiplayer behavior is defined in `docs/GAMEPLAY_SPEC.md`.
- Arcade reaction time starts at first render and uses the original compatible
  touch-contact timestamp. Expiry/input resolves once.
- Zen is local, unranked, unrewarded, and ephemeral.
- The owner-approved Multiplayer v2 implementation uses one identical shared
  board, 2–4 own-color seats, shared Arcade rules, a native WSS client and persistent
  Vapor authority. Gameplay revision 2 adds Arcade quiet intervals and unique
  changing colors, non-player-color persistent decoys, and first-claim hearts.
  Shared contention/delivery can extend personal spacing; no network wait belongs
  on the local feedback path. Revision-1 clients use separate compatible rooms.
- V2 is `multiplayer-shared-arcade-v2`, protocol `2`. Owner-approved revision 3
  enables a fresh server-reported leaderboard and two earned coins per cumulative
  connected/alive minute; older revisions remain unranked/unrewarded.
  No live GameKit, FAST seals, peer transcript or v1 client mutation path. Preserve
  historical v1 evidence and unrelated Game Center account/publication.
  Primary session and confirmed name suffice; Game Center is not a v2 prerequisite.
- PHP stores isolated service-reported v2 aggregates, not independent replay proof.
  PHP alone derives idempotent, generation-bound coin credits from service evidence.
  No Multiplayer achievements or Game Center publication. Keep deployment evidence
  separate from local implementation; never reinterpret v1 or backfill old results.
- Uploaded build 24 is the historical v1 beta, not today's v2 source. Follow
  `docs/CURRENT_VERSION.md`; configuration/build number alone never proves release.
- The server owns identity, names, ranked attempts, proof replay, score, coins,
  achievements, catalogs, cosmetics, moderation, and account ledger state.
- StoreKit proves purchase/refund state; value appears only after verified server
  reconciliation. Never trust a client-authored amount, price, balance, or flag.
- Game Center is secondary identity. iOS never publishes scores/achievements
  directly and never treats Game Center as a PimPoPom login.
- Ads require current UMP permission and authoritative non-ad-free state. Debug
  uses demo inventory; production activation requires explicit release authority.
- Themes and pets are presentation only. Asset origin and public rights gates stay
  recorded even when the asset is already in TestFlight.

## Required checks

Run `Scripts/check.sh` and `git diff --check` before implementation handoff. The
script is the required non-device gate: project generation, formatting, builds,
unit/UI tests, static configuration, privacy, and asset provenance.

Behavior changes require tests. API, identity, GameKit, StoreKit, ads, and privacy
changes require focused contract/integration coverage. Touch, audio, haptics,
GameKit, ads, StoreKit, lifecycle, and 60/120 Hz claims require named physical
iPhone evidence before being called device-validated.

## Release and handoff

Production deployment, App Store submission, live ads, and paid-product activation
require explicit owner authorization. Release only from an exact clean reviewed
commit and record source, version/build, toolchain, archive checksum, symbols,
backend tuple, App Store Connect ID/state, and rollback target.

Every handoff reports intentional files, checks and devices, remaining API/privacy/
StoreKit/ad/accessibility/device gaps, branch and commit, release identifiers if
any, and unrelated dirty files preserved.
