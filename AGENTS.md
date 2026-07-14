# PimPoPom repository instructions

These rules apply to every task in this repository. A specific user instruction takes precedence.

## Start every task safely

1. Run `git status --short` before editing.
2. Read the relevant parts of `README.md` and `docs/DECISIONS.md`.
3. Read the domain document for the work: gameplay, API, monetization/privacy, assets, testing, or release.
4. For visual work, inspect `docs/DESIGN_QA.md`; it is historical evidence, never release truth.
5. For branding, audio, fonts, or pet assets, read the matching `assets/**/SOURCES.md` record and retain provenance plus rollback masters.

The PimPoPom repository may be stored inside an ignored folder of another checkout. Git boundaries matter:

- Never edit, stage, commit, reset, stash, or clean the parent legacy repository as part of a PimPoPom task.
- Run Git commands with this repository as the working directory and confirm the top level with `git rev-parse --show-toplevel` before staging.
- Treat unexplained changes as belonging to the user or another task. Stop if intended edits overlap them.
- Use one editing task per checkout. Run parallel implementation in separate worktrees and `codex/<task>` branches.
- Commit only intentional PimPoPom files. Never commit signing keys, profiles, OAuth secrets, App Store keys, ad credentials, session tokens, or production configuration.

## Sources of truth

| Concern | Source |
| --- | --- |
| Code and shipped resources | Exact PimPoPom Git commit |
| Accepted behavior | `README.md`, `docs/GAMEPLAY_SPEC.md`, and accepted decisions at that commit |
| Proposed work | `docs/MIGRATION_PLAN.md` and proposed decisions |
| Backend behavior | Versioned server implementation plus `docs/API_CONTRACT.md` compatibility tests |
| Economy and StoreKit state | Server ledger plus App Store-signed transactions; never the device cache alone |
| TestFlight/App Store release | App Store Connect build tied to its Git commit and build number |
| Visual evidence | `docs/DESIGN_QA.md` and referenced captures |
| Asset rights and masters | Matching `assets/**/SOURCES.md` records |

Do not describe a proposal as shipped, a simulator test as device validation, a TestFlight build as App Store production, or a client-generated run as human verified.

## Architecture boundaries

These boundaries implement accepted decision P-003 and remain binding until a later decision supersedes them.

- `PimPoPomCore`: deterministic configuration, injected time/random choices, game state, scoring, ratings, streaks, decoys, timers, and proof events. Seeded randomness is a test fixture tool, not an implied production protocol. No SwiftUI, SpriteKit, UIKit, networking, storage, audio, ads, or StoreKit imports.
- `PimPoPomContracts`: service-facing protocols and shared models used by features/gameplay; depends only on core/value types.
- `PimPoPomGameplay`: SpriteKit rendering plus presentation/touch timestamp bridge. It renders core snapshots and converts input into core commands; it does not duplicate rules.
- `PimPoPomFeatures`: SwiftUI screens and coordinators. It consumes state and invokes use cases without owning backend authority.
- `PimPoPomServices`: typed API, identity, Keychain session storage, StoreKit, ads, audio, haptics, persistence, and app lifecycle adapters.
- `PimPoPomDesign`: theme tokens and reusable visuals. Themes cannot change gameplay semantics.
- The app target is the composition root. Dependencies point inward toward protocols and `PimPoPomCore`.

Use structured concurrency. Keep UI and SpriteKit mutations on the main actor, isolate mutable service state, make cancellation explicit, and do no network, disk, decoding, purchase, or ad work on the render/touch path.

## Gameplay and data invariants

- Preserve every accepted rule in `docs/GAMEPLAY_SPEC.md` through deterministic tests before polishing presentation.
- Measure a reaction from the frame that presents the target to the original compatible touch-contact timestamp. Expiry and input must use one monotonic timebase and resolve exactly once.
- Arcade wire mode may remain `normal` for compatibility; player-facing text is **Arcade**. The app and storefront name is always **PimPoPom**.
- Zen remains endless, local, unranked, unrewarded practice with explicit in-memory results only.
- Ranked results and gameplay rewards remain **protocol verified**, not human verified or bot-proof.
- Anonymous play cannot create durable coins, paid items, achievements, or ranked results.
- Never trust a client-authored score, elapsed time, price, balance, ownership, entitlement boolean, StoreKit payload, or ad-SDK removal state. Apple-signed StoreKit transaction/entitlement state must be cryptographically verified; the server remains authoritative for account-bound coin credit and ledger state.

## Ads and purchases

The requested UI locations are accepted. Do not implement or ship paid value until P-010 and the open product/refund/accounting decisions are accepted. The StoreKit details below describe the proposed model and become binding only when that decision is accepted.

- Use test ad identifiers in debug, tests, screenshots, and CI. Production ad IDs must be injected only into signed release configuration.
- The ad host is reserved at the bottom of gameplay below the **Speed streak meter** (the requested “speed rating bar”) and above the bottom safe-area inset. It cannot overlay the board, intercept board touches, or resize active gameplay when an ad loads, fails, or disappears. It may collapse or re-layout only between runs under the accepted compact-device/ad-free policy.
- The main-menu **Remove Ads** action stays in the lower-right safe layout and opens the accepted purchase/restore flow; the proposed product is a StoreKit non-consumable.
- **Buy Coins** appears in both Theme Shop and Pet Shop and opens the same server-backed coin-store flow.
- Under the proposed model, StoreKit coin packs are consumables. Credit them once, on the server, from verified signed transactions. Handle pending, cancelled, duplicate, refunded, revoked, offline, and account-mismatch states explicitly.
- Decide earned-versus-purchased coin accounting before IAP implementation. Administrative resets must not silently destroy paid value.
- Consent must complete before requesting ads. Do not request tracking permission unless the accepted advertising design truly uses tracking.

## Audio and asset rules

- Use original or correctly licensed material only. Record source, creator/tool, licence, prompts where applicable, transformations, hashes, and retained masters.
- The new brand sting is an original three-part **Pim** low → **Po** mid → **Pom** higher voice-like cue. Do not imitate an identifiable person's voice.
- The launch screen is static. A sting may play only after the app is active, must never delay interaction, and must respect Sound FX preference, system audio expectations, interruptions, and backgrounding.
- Preload reaction-critical cues, cap overlapping voices, release retired voices smoothly, and skip unready cues rather than playing them late.
- Haptics must degrade gracefully on unsupported devices and respect the user's setting and accessibility preferences.

## Required checks

Once the project bootstrap creates `Scripts/check.sh`, run it before every implementation handoff. It must include formatting, build, unit/parity tests, UI/static checks, privacy-manifest validation where available, and `git diff --check`.

Behavior changes require tests. New modules require deterministic import/build coverage. Purchase, ads, identity, and API changes require sandbox or staging integration tests in addition to mocks.

Before describing work as device-validated, test on physical iPhones at both 60 Hz and 120 Hz where supported. Touch timing, audio latency/mix, haptics, interruptions, safe areas, thermal behavior, ad placement, StoreKit sandbox, and background/foreground transitions cannot be signed off by Simulator alone.

## Release safety

- Production deployment and App Store submission require explicit user authorization.
- Release only an archived build from a clean, reviewed, committed source tree.
- Record commit SHA, marketing version, build number, Xcode/Swift version, dependency resolution, archive checksum, backend API/ruleset compatibility, TestFlight build, App Store phased-release state, and rollback target.
- Retain the prior version's exact source, archive, dSYMs, release record, and backend compatibility until the supported-client window closes. Apple does not provide an instant binary rollback; recovery means halting phased release where possible and submitting a corrective version.
- Do not enable live ads, paid StoreKit products, production API credentials, analytics, or attestation enforcement in an unreviewed build.

## Handoff checklist

Report:

- outcome and files intentionally changed;
- checks, simulators, and physical devices used;
- API, StoreKit, ad, privacy, accessibility, and device limitations;
- branch and commit SHA, when created;
- build/TestFlight/App Store identifiers, when released;
- unrelated dirty files preserved.
