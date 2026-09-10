# Current binding decisions

This is a current-state register, not a chronological log. Only the choices below
are binding at this commit. Superseded material remains available in Git history.

## D-01 — Keep PimPoPom native and repository-separated

Status: implemented.

PimPoPom is an iPhone-only native app. This repository owns Swift code, tests,
assets, client contracts, and the separate `Server/` Vapor package. The PHP/web
repository owns identity, durable account data, the v2 bridge, and its deployment.
Neither repository is edited implicitly for the other.

## D-02 — Keep deterministic rules in one pure Swift package

Status: implemented.

`PimPoPomCore` owns game configuration, rules, scoring, timing, Arcade proof tuples,
and the v2 protocol/room engine without Apple frameworks. The app target keeps
`Design`, `Features`, `Gameplay`, and `Services` as folders with inward dependency rules.
Split them into modules only when a concrete build/ownership benefit justifies it.

## D-03 — Measure reaction input at presentation/contact boundaries

Status: implemented.

The reaction clock begins on the first frame that exposes a target. Resolve from
the original compatible `UITouch.timestamp` on the same monotonic timebase. Input
at the deadline is late; pre-presentation input is ignored; input and expiry may
resolve only once. No network, disk, decoding, ad, or purchase work belongs on the
touch path.

## D-04 — Preserve the current three mode contracts

Status: Arcade/Zen retained; Multiplayer v2 revision 2 released in the build-26 beta.

Arcade is endless until three mistakes and is the only coin/achievement-eligible
mode. Zen is endless local practice with no deadlines, decoys, durable result, or
rewards. Multiplayer v2 is 2–4-player own-color play on one identical shared board,
with individual three-life state. Shared hearts can restore one life up to three;
eliminated seats remain spectators. It ends when all are out or the 15-minute
bound is reached, after the input admission horizon. No Multiplayer coins/achievements.
Arcade/Zen rules remain in `docs/GAMEPLAY_SPEC.md`; v2 rules and deliberate shared
board adaptations are in `docs/MULTIPLAYER_V2_REBUILD.md`.

## D-05 — Keep identity provider-separated

Status: implemented.

Apple and Google proofs are verified server-side and map to one internal UUID.
A second provider is attached only through explicit recent-authenticated linking;
email, relay email, nickname, device, StoreKit, and Game Center never merge
profiles. Public nicknames are confirmed, whitespace-free Unicode and server-unique.

## D-06 — Treat Game Center as a secondary publication identity

Status: implemented.

Game Center authenticates independently and nonblockingly at launch. After primary
sign-in the app silently reconciles fresh persistent Game Center proof; Profile
offers **See stats**, not manual link/disable controls. Game Center never logs into
PimPoPom, grants value, or owns results. PHP alone publishes allowlisted scores and
achievement completion; iOS never calls Apple submission APIs directly.

## D-07 — Keep durable gameplay and economy authority off-device

Status: implemented.

PHP issues ranked attempts, replays proofs, stores immutable results, moderates,
and owns achievements, coins, debts, catalog prices, purchases, ownership, and
selection. The client may render fallbacks but never invents authoritative score,
balance, price, ownership, or eligibility. Replayed Arcade and clean historical
v1 results are called protocol-verified, never human-verified or bot-proof.
V2 alpha aggregates are service-reported and unranked, as scoped in D-12.

## D-08 — Use signed StoreKit state plus a source-aware server ledger

Status: implemented; public validation remains gated.

StoreKit 2 proves transactions, entitlements, refunds, and revocations. PHP credits
each transaction idempotently and tracks earned/purchased provenance, debt, and
ad-free sources. Four coin packs and one standalone Remove Ads non-consumable are
accepted. Coin packs also grant account-bound ad-free; only the standalone product
is Apple-restorable and Family-Shareable.

## D-09 — Gate advertising through consent and authoritative entitlement

Status: implemented in test/beta configurations.

UMP refreshes before any eligible ad request. Unknown or ad-free account state
starts no GMA inventory. Eligible banners use a fixed 320×50 host outside the board;
the third eligible Arcade/Zen completion makes an interstitial due. Debug/nonowner
beta uses demo inventory; owner production units run only in registered Test mode.
Checked-in Release is disabled until an explicitly authorized public configuration.

## D-10 — Keep presentation configurable but rules invariant

Status: implemented.

Default/Disco are free; Light costs 50 coins and Pixel 100. Pet prices are Foka 10,
Kesha 20, Tauta 50, Misha 100, and Pancake 500; special pets are server-granted.
Themes, glyphs, icons, pets, audio, and haptics never alter timing, hit regions,
score, or proof. Asset source/licence records and rollback masters are retained.

## D-11 — Keep Sound FX and Music independent

Status: implemented.

Both default on and remember separate opt-outs/volumes. Sound FX owns theme tap
tones, life loss, and the Pim–Po–Pom sting; Music owns menu/gameplay loops. Disabled
categories load nothing. Preload critical cues, bound overlap, skip late cues, and
handle lifecycle/interruption without blocking play.

## D-12 — Replace live Multiplayer v1 with an isolated v2 authority

Status: v2 revision 1 retained for build 25; revision 2 released in the build-26 beta.

Native `URLSessionWebSocketTask` connects to one persistent Vapor 4 room service.
The shared pure Swift engine owns targets, input admission, scores and lives;
the room service owns membership, revisioned Ready and atomic Start. Remove the
old GameKit peer coordinator, FAST seals/frontiers, unanimous transcripts and v1
client mutations. Preserve the hub/waiting-room identity, historical v1 leaderboard
reads and unrelated Game Center account/publication behavior. Primary sign-in and
confirmed nickname are required; Game Center is not a v2 entry requirement.

V2 is exactly `multiplayer-shared-arcade-v2`, protocol `2`. PHP tickets and service
introspection/result endpoints are additive and isolated. PHP stores service-reported
unranked aggregates; it does not independently replay v2 inputs. No public v2
ranking, ranked season, reward, achievement or Game Center publication is enabled.
Historical clean v1 results remain `peer_consistent_v1`; do not relabel them.

Negotiate gameplay revision separately in socket Hello/Welcome: an omitted
revision means legacy `1`; build 26 explicitly requires `2`. Partition browsing,
joining and resuming by that revision. Never feed new pickup gameplay to build-25
clients, or silently downgrade a new client when the service is not ready.
Revision 2's cumulative misses require the separate additive PHP migration 024
and compatible validator before server rollout; no authentication protocol change.

## D-13 — Share one board with Arcade tempo and safe color ownership

Status: owner-directed revision 2 released to TestFlight; physical-device acceptance pending.

Every seat sees the same board. Waiting for an own-color target is accepted,
including on 1×1. There is no fixed turn order: random arbitration permits repeats,
and different owners can overlap when cells are free. Grow to 2×2 after four total
valid hits and 4×4 at 40 seconds. Share Arcade configuration, difficulty and scoring
instead of copying its numerical rules. Every correct hit starts an Arcade quiet
interval that gates newly issued targets for every owner; already announced
windows remain immutable and may overlap. Cell contention and delivery can still
extend personal spacing; exact independent personal cadence is not promised.

After the ten-second Arcade boundary, valid hits rotate the owner's color without
colliding with any assigned player or live-decoy color. Decoys never use any
player's color, have no exclamation marker, and survive correct taps for their
normal lifetime. One global Arcade decoy cap reserves one target cell rather than
one per player. Neutral, first-admitted-claim hearts restore one life up to three
without reviving spectators, granting points or changing target timing.

Reuse Arcade's SpriteKit rendering and original-contact bridge; project local
feedback without waiting for a network round trip. Server receipts/snapshots reconcile
that presentation. A disconnected seat has a 15-second return grace while others
continue. No peer ACK barrier is permitted. Latency and 60/120 Hz targets remain
acceptance goals, not measurements. Detailed behavior and gaps live in the v2 brief.

## D-14 — Keep release evidence exact

Status: implemented as process.

An exact Git commit, archive identity, test evidence, App Store Connect state, and
rollback target define a release. Simulator, physical-device, TestFlight, and
production evidence are reported separately. Production submission, live ads,
paid activation, and deployment require explicit owner authorization.
