# Current binding decisions

This is a current-state register, not a chronological log. Only the choices below
are binding at this commit. Superseded material remains available in Git history.

## D-01 — Keep PimPoPom native and repository-separated

Status: implemented.

PimPoPom is an iPhone-only native app. This repository owns Swift code, tests,
assets, and client contracts; the PHP/web repository owns server implementation
and deployment. Neither repository is edited implicitly for the other.

## D-02 — Keep deterministic rules in one pure Swift package

Status: implemented.

`PimPoPomCore` owns game configuration, rules, scoring, timing, Multiplayer replay,
and proof tuples without Apple frameworks. The app target keeps `Design`,
`Features`, `Gameplay`, and `Services` as folders with inward dependency rules.
Split them into modules only when a concrete build/ownership benefit justifies it.

## D-03 — Measure reaction input at presentation/contact boundaries

Status: implemented.

The reaction clock begins on the first frame that exposes a target. Resolve from
the original compatible `UITouch.timestamp` on the same monotonic timebase. Input
at the deadline is late; pre-presentation input is ignored; input and expiry may
resolve only once. No network, disk, decoding, ad, or purchase work belongs on the
touch path.

## D-04 — Preserve the current three mode contracts

Status: implemented.

Arcade is endless until three mistakes and is the only coin/achievement-eligible
mode. Zen is endless local practice with no deadlines, decoys, durable result, or
rewards. Multiplayer is 2–4-player own-color play, gives no coins/achievements,
and ends only after all participants are out. Exact rules live in
`docs/GAMEPLAY_SPEC.md`.

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
balance, price, ownership, or eligibility. Results are called protocol-verified,
never human-verified or bot-proof.

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

## D-12 — Use peer-consistent Multiplayer v1

Status: implemented and retained by the build-23 candidate.

PHP owns authenticated lobbies, stable seats/colors, immutable manifests, replay,
settlement, and ranked rows. `GKMatch` owns live traffic. A fixed coordinator
produces one compact transcript and every participant submits that same seat-only
stream. Clean matching results are protocol-verified and peer-consistent, not
server-authoritative or collusion-proof. Protocol v1 has no coordinator migration.

## D-13 — Make Multiplayer feel immediate with prediction plus reconciliation

Status: implemented in the build-23 source candidate; not yet uploaded.

Preserve deterministic canonical replay while acknowledging local contact within
one display frame. Prediction changes presentation only; reliable evidence,
resolutions, cumulative seals, exact control acknowledgements, and bounded causal
snapshots converge every peer on one transcript. Ordinary loss remains interactive:
recovery is hidden below one second, uses a small `Catching up` HUD from 1–15
seconds, and cancels only after the 15-second recovery bound. Real disconnects
coordinate a logical pause. Start/plan output cannot advance until its reliable
ordering barrier is physically established, and pause remains authoritative until
Resume has been physically accepted for every intended peer. Its exact-ACK retry is
retained in the background and cannot create a second recovery window. Build 23
rejects incompatible live-wire peers before start.
Host migration, custom LAN routing, and concurrent per-seat targets remain
separately versioned work. Current behavior and gates are in
`docs/MULTIPLAYER_FAST_TASK.md`.

Any tuple/proof/backend change required by this work is separately versioned and
implemented in the backend-owning repository. No iOS-only release may silently
reinterpret the deployed v1 transcript.

## D-14 — Keep release evidence exact

Status: implemented as process.

An exact Git commit, archive identity, test evidence, App Store Connect state, and
rollback target define a release. Simulator, physical-device, TestFlight, and
production evidence are reported separately. Production submission, live ads,
paid activation, and deployment require explicit owner authorization.
