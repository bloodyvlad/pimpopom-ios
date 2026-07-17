# PimPoPom decision log

This file records durable product and architecture choices for the native iOS game.

## How to use this log

- **Accepted** decisions define the committed target until superseded.
- **Proposed** decisions are recommendations awaiting explicit acceptance or implementation review.
- **Superseded** decisions remain for history and link to their replacement.
- Plans, experiments, and uncommitted code do not silently change an accepted decision.
- Each new record receives the next stable `P-###` identifier.

## P-001 — Build PimPoPom as a separate native iOS repository

- Date: 2026-07-14
- Status: Accepted

Context: The existing browser game has web, PWA, PHP, and legacy rollback concerns that do not belong in an Xcode release lifecycle.

Decision: Build the native iOS game in its own Git repository. Its app, storefront, icon, support, analytics, and player-facing product name is **PimPoPom**. The local repository may live inside the legacy checkout only while the parent excludes the entire folder locally.

Consequences: Xcode signing, App Store builds, Swift dependencies, and release history stay isolated. Shared backend changes still occur in the repository that owns the backend and must be coordinated through versioned contracts.

Revisit when: A deliberate multi-platform monorepo with generated shared contracts becomes operationally simpler.

## P-002 — Freeze a reviewed migration baseline without modifying it

- Date: 2026-07-14
- Status: Accepted

Context: A moving source makes behavioral parity impossible to measure, while the deployed state cannot be inferred from local documentation alone.

Decision: Use legacy source commit `675551adc715942ce2512c14d396d5d14e763f02` as the initial behavioral and fixture baseline. Treat it as source evidence only, not deployment evidence. Do not implement PimPoPom by editing the legacy repository's current `main` branch.

Consequences: Later web changes are explicit cherry-pick/reconciliation decisions. Every copied asset requires a rights and provenance review. Backend work needed for native clients is separately scoped and reviewed.

Revisit when: A newer source commit is intentionally adopted and parity fixtures are regenerated.

## P-003 — Separate the deterministic game core from Apple frameworks

- Date: 2026-07-14
- Status: Accepted

Context: Reaction timing, scoring, decoys, streaks, Zen behavior, and ranked proof events must be testable without a renderer or device.

Decision: Implement a pure Swift `PimPoPomCore` module with injected monotonic time and randomness. Deterministic tests use a seeded generator; production uses an accepted system random source. A server-supplied gameplay seed would be a new ruleset/proof protocol and requires its own backend decision. Use SwiftUI for application surfaces and SpriteKit for the latency-sensitive reaction scene. Renderers and services consume snapshots and issue commands; they do not duplicate rules.

Consequences: Cross-runtime golden fixtures can prove migration parity. SpriteKit, SwiftUI, ads, audio, networking, and StoreKit can evolve without rewriting the engine.

Revisit when: A measured prototype demonstrates a simpler renderer with equal or better presentation-to-touch correctness on supported 60 Hz and 120 Hz devices.

## P-004 — Extend the authoritative backend through a native versioned contract

- Date: 2026-07-14
- Status: Proposed

Context: The current service owns identity, run tickets, proof replay, ranks, achievements, pets, themes, and coins, but its Google Web login, same-origin cookie, CSRF, session binding, and exact web build gate are browser-oriented.

Decision: Keep one authoritative economy and leaderboard, but add an explicitly versioned native authentication/session and ranked-run contract. Never spoof a web build or copy server authority into the app. Separate client build/version from shared ruleset and proof versions.

Consequences: Native staging endpoints and contract tests are prerequisites for ranked play and purchases. The app can offer local practice while the service is unavailable, but cannot promote that run later.

Revisit when: Product strategy deliberately chooses an iOS-only season or a new shared backend service.

## P-005 — Offer Apple and Google identity with explicit account linking

- Date: 2026-07-14
- Status: Proposed

Context: Existing players use Google, while a native App Store app using third-party primary login generally needs an equivalent privacy-preserving option. Account creation also requires an accessible deletion path for App Store submission.

Decision: Add Sign in with Apple through AuthenticationServices and retain Google Sign-In for cross-platform users. The server validates both providers, maps them to one internal player UUID through a deliberate linking flow, stores provider-subject digests for identity plus only encrypted server-side revocation material a provider requires, and exposes in-app account deletion. Never merge accounts from matching email alone.

Consequences: Native sessions live in Keychain, provider tokens are exchanged rather than used as long-term app sessions, and account deletion/revocation semantics must cover ledger and legally retained audit data.

Revisit when: Google login is removed from PimPoPom or an App Store guideline exception is documented and accepted.

## P-006 — Preserve the established game rules before adding native polish

- Date: 2026-07-14
- Status: Accepted

Context: A platform migration cannot be evaluated if gameplay balance changes at the same time.

Decision: Port the Arcade and Zen behavior in `docs/GAMEPLAY_SPEC.md` with cross-runtime golden fixtures before adding platform-specific polish. User-facing naming changes to PimPoPom; compatibility identifiers such as wire mode `normal` may remain internal.

Consequences: Intentional balance changes require new decisions and fixture updates after parity. Native timing may reduce platform bias, but scoring thresholds do not change silently.

Revisit when: Native playtesting provides measured evidence for a balance change.

## P-007 — Reserve the bottom ad placement without disturbing gameplay

- Date: 2026-07-14
- Status: Accepted

Context: An asynchronously loaded banner can shift the board, intercept reaction taps, overlap safe areas, or create accidental clicks.

Decision: Place the ad container at the absolute bottom of gameplay, below the **Speed streak meter** (the component referred to in the request as the speed rating bar) and above the bottom safe-area inset. The bottom order is pet if visible, Speed streak meter, separator, reserved ad host, then safe-area inset. Reserve its size before a run. Loading, no-fill, consent, offline state, and removal cannot resize an active board or move a target. Ads never overlay gameplay. The initial recommendation keeps this host empty during an active rapid-tapping run and fills ads only on non-active surfaces until the ad provider's policy and accidental-tap review approve otherwise.

Consequences: Compact-device layout must budget for the slot or suppress/collapse it only between runs when the accepted minimum board size cannot be met. Confirmed Remove Ads entitlement may also re-layout only between runs. Touch hit-testing and accessibility tests must prove that the banner cannot receive board touches.

Revisit when: Product evidence favors ads only between runs or a different non-disruptive format.

## P-008 — Provide Remove Ads and Buy Coins entry points

- Date: 2026-07-14
- Status: Accepted

Context: PimPoPom needs clear, platform-compliant monetization entry points without allowing UI state to grant value.

Decision: Put **Remove Ads** in the lower-right safe layout of the main menu. Put **Buy Coins** in both Theme Shop and Pet Shop; both open the same coin-store surface.

Consequences: The proposed implementation uses a StoreKit non-consumable for Remove Ads and StoreKit consumables for coin packs, with server verification and idempotent ledger credit. Restore Purchases must be visible for Remove Ads. Product types/catalog, SKU prices, pack sizes, paid-versus-earned accounting, refunds, revocations, guest purchases, and reset behavior remain release-blocking decisions; a button alone cannot ship the economy.

Revisit when: Monetization research selects a subscription, ad-free paid app, or no-IAP model instead.

## P-009 — Create an original PimPoPom visual and sonic identity

- Date: 2026-07-14
- Status: Accepted

Context: The native game needs its own memorable identity and cannot retain the legacy player-facing brand.

Decision: Generate and review a new PimPoPom logo/app icon system and an original voice-like launch sting: **Pim** at a low pitch, **Po** in the middle, and **Pom** higher. Do not imitate an identifiable person's voice. Retain editable/lossless masters, runtime exports, prompts or performer consent, licences, and hashes.

Consequences: The iOS launch screen remains static. The short cue plays only after activation through the normal audio preference/session lifecycle, never delays interaction, and is tested against silent mode, interruptions, and accessibility expectations.

Revisit when: Brand testing selects another identity or an audio-free launch.

## P-010 — Make StoreKit and the server authoritative for paid value

- Date: 2026-07-14
- Status: Proposed

Context: Selling coins changes the inherited prototype assumption that coins have no real-money value. Client-only verification would permit replay, account mismatch, lost purchases, and destructive moderation of paid value.

Decision: Verify App Store-signed transactions on the server, bind purchases to an internal account with `appAccountToken`, use immutable transaction IDs as idempotency keys, process server notifications/refunds, and keep purchased-value provenance distinct enough to reconcile moderation safely. Never trust a device balance, local entitlement, product price, or unverified transaction.

Consequences: StoreKit sandbox, interruption, pending purchase, duplicate, reinstall, refund, chargeback, and account-deletion tests become release gates. The exact earned/purchased spend order must be accepted before implementation.

Revisit when: Coins are not sold or the entire economy is redesigned.

## P-011 — Use Game Center only as a supplementary social surface

- Date: 2026-07-14
- Status: Proposed

Context: Game Center offers familiar leaderboards and achievements but does not understand the server's proof status, economy generation, moderation, or exact-result context.

Decision: Keep the PimPoPom service authoritative. If a Game Center entry is presented as a mirror of protocol-verified state, bind the authenticated Game Center player identity on the server and submit the verified score/achievement through Apple's supported server API. A client-submitted Game Center board must instead be labeled auxiliary and unverified. Game Center identity never grants profile ownership, coins, purchases, or moderation rights.

Consequences: The app can provide native social discovery without creating a second economy. Failed Game Center submissions are retryable side effects and do not roll back a verified result. A later server quarantine or deletion may not remove an already mirrored Game Center score; correction, season separation, and moderation visibility must be designed before enabling the mirror.

Revisit when: Game Center becomes the only competitive identity or is removed from scope.

## P-012 — Describe ranked results as protocol verified, never bot-proof

- Date: 2026-07-14
- Status: Accepted

Context: Proof replay and App Attest can reject aggregate forgery, invalid transitions, and many modified clients, but cannot prove a human made every physical tap.

Decision: Use **protocol verified** for accepted results. App Attest is a risk signal and request-integrity layer, not proof of humanity.

Consequences: Moderation remains reversible and evidence-based. Marketing, UI, support, and release notes cannot claim bot-proof or human-verified competition.

Revisit when: Independently validated hardware and operational controls support a stronger claim.

## P-013 — Ship an offline technical alpha before platform services

- Date: 2026-07-15
- Status: Superseded by P-014

Context: Xcode and Simulator are installed, and the immediate goal is the shortest route to a native build on an iPhone SE (3rd generation). The current web game has no live ads or purchases, and production ownership, accounting, and legal work can follow once gameplay is stable.

Decision: Build the first PimPoPom alpha as a development-signed, local-only iPhone app. Start with the deterministic Arcade core and SpriteKit scene, complete local Arcade/Zen parity, then validate iPhone SE 2022 and iPhone 13 mini at 60 Hz plus iPhone 13 Pro at adaptive 120 Hz. Use disabled no-network adapters for ads and purchases; add no vendor SDK, StoreKit product, Google sign-in, or backend dependency during this track. The bootstrap uses a replaceable development bundle identifier and automatic signing.

Consequences: Google OAuth is not required to install or play the first alpha. The immediate owner action is only local Apple code signing, device trust, and Developer Mode. Profiles, ranking, economy, shops, final branding/audio, ads, purchases, legal, accounting, storefront, and production credentials remain later phases. Simulator evidence covers builds and layout only; real refresh/touch timing requires the named physical devices.

Revisit when: The local gameplay device matrix passes and the next integrated service slice is selected.

## P-014 — Reuse the deployed PHP contract for the internal native alpha

- Date: 2026-07-15
- Status: Accepted

Context: The owner explicitly accepted shared internal use of the current Hostinger backend, database, players, coins, and leaderboards to reach a playable iPhone build quickly. The deployed service already accepts Google ID tokens whose audience is the existing Web OAuth client, secure cookie sessions with CSRF, and proof-v1 Arcade submissions for build `20260715-1`.

Decision: For owner-only internal testing, PimPoPom may reuse the existing extensionless `/api/*` contract and production Season 1 data. Use one cookie-enabled `URLSession`, bootstrap CSRF through `/api/session`, configure Google Sign-In with a new iOS client ID plus the existing Web client ID as `serverClientID`, and submit only the exact `reaction-proof-v2` proof-version-1 event stream. If sign-in, nickname confirmation, or run-ticket issuance is unavailable, start an explicitly local practice run instead. Do not change or deploy the PHP backend from this repository.

Consequences: The internal binary identifies ranked attempts with the server's accepted Web build ID `20260715-1`; this is a deliberate temporary compatibility exception to P-004, not a claim that PimPoPom is that web binary. Native and browser clients share the one-open-attempt-per-player rule and production data. The Google iOS OAuth ID stays in ignored local configuration. Ads and StoreKit remain disabled. Before any external TestFlight/App Store distribution, replace this exception with an accepted native client/build contract, complete identity/account review, and use staging/synthetic integration data.

Revisit when: The first physical-device alpha works, the deployed web build gate changes, or any build is prepared for someone beyond the owner/internal testers.

## P-015 — Port the existing earned-coin cosmetics and audio into the internal alpha

- Date: 2026-07-15
- Status: Accepted; Pancake restriction superseded by P-018

Context: The owner accepted the playable native checkpoint and asked to continue with the current Pet Shop, Theme Shop, earned coins, music, and sounds. The compatibility backend already owns the catalog prices, balance, ownership, selection, pet visibility, and atomic spending; it has no StoreKit coin-credit route. The reviewed web source also contains four fixed theme audio suites and current pet presentation assets.

Decision: The internal alpha reads `/api/themes` and `/api/pets`, displays server names/prices/state, and sends only stable item IDs through the existing authenticated CSRF mutations. All economy mutations are serialized, and a response may update the client only while it still belongs to the current player/session. Default and Disco may be selected locally while signed out; no other local state grants ownership, coins, or paid value. Both shops expose one disabled explanatory Buy Coins sheet. Use code-native theme presentation; use parent web repository commit `7582b2d` as the visual parity reference for current pet assets, habitats, placement, and interaction; bundle reviewed Foka/Kesha/Tauta/Misha/Mitsuri runtime art plus server-derived Muse special-pet art; derive special-pet visibility only from the backend; and block new Pancake purchases while showing labelled code-native placeholder art. Shop pets remain static until tapped for a one-shot preview, while the resolved visible pet appears consistently on eligible menu and gameplay surfaces. Freeze the selected theme and resolved pet for each active run. Use one lazy `AVAudioEngine` with independent persisted Sound FX and Music controls, the exact four fixed menu/gameplay/tap suites, the shared loss cue, and the original deterministic rising Pim–Po–Pom activation-cue candidate.

Consequences: The shared Hostinger balance and existing atomic shop transactions remain authoritative; this repository adds no PHP, StoreKit, ad, or coin-generation route. Masters, generators, provenance, and hashes stay outside the app bundle while reviewed runtime files are deterministic build resources. Automated contracts and asset checks are required, but physical listening, touch/layout review, Silent switch, interruptions, and route changes remain acceptance gates. Pancake replacement art, final audio/logo acceptance, paid coins, and commercial ownership remain deferred.

Revisit when: The compatibility backend changes its catalog/session contract, replacement Pancake art is approved, a public distribution is prepared, or StoreKit coin products are deliberately resumed.

## P-016 — Translate the reviewed web menu and themes into native views

- Date: 2026-07-16
- Status: Accepted

Context: The first native alpha proved the SwiftUI/SpriteKit architecture and backend path, but its menu, backgrounds, controls, typography, and Theme Shop diverged visibly from the established game. The owner asked to continue as close as practical to the original rather than restyle the port.

Decision: Use parent SpeedyTapper commit `923a38e` as the fixed visual contract for the main menu and four themes, while retaining commit `7582b2d` as the pet-presentation contract. Translate the reviewed geometry, color tokens, gradients, texture use, compact wordmark, mode hierarchy, feature accents, and two-column Theme Shop into native SwiftUI/SpriteKit components. Bundle the exact reviewed Jersey 10 font and Disco textures with retained sources, licence/provenance, hashes, and deterministic resource checks. Keep native navigation, accessibility, deterministic engine, backend authority, audio lifecycle, ad reservation, and StoreKit placeholders; do not embed the browser implementation in a `WKWebView`.

Consequences: PimPoPom can closely match the established visual identity while remaining a maintainable native game. Deterministic UI-test theme fixtures and compact-menu geometry tests become regression gates. Exact HTML/CSS reuse is intentionally unavailable in a native renderer, so CSS effects are translated to equivalent SwiftUI/SpriteKit composition. Achievements remains an explicitly labelled native placeholder until its backend feature slice is ported.

Revisit when: A deliberately new PimPoPom brand system is accepted, the web design contract is intentionally advanced, or measured native accessibility/performance requires a documented visual exception.

## P-017 — Use fixed native screens while preserving the current game presentation

- Date: 2026-07-17
- Status: Accepted; pet-facing detail superseded by P-019

Context: The scrollable floating web dialog was appropriate for a browser but made the native app feel like a restyled port. The owner requested a fixed main menu, closer gameplay chrome, repaired pet behavior, and specific Light/Pixel corrections while retaining the current rules and shared backend. Parent SpeedyTapper commit `209ee6ca84b17bc81144d2dc60c613feeae05dc0` adds the current menu-slogan pool and rotation behavior.

Decision: Keep the main menu inside the device safe area without a `ScrollView` or floating dialog panel; feature catalogs and settings may scroll where their content requires it. Remove build, backend, and season diagnostics from the menu footer. Keep Remove Ads at lower right and route it to a no-entitlement StoreKit placeholder. Add one persisted Glyphs preference that controls theme previews, the target header, feedback copy, and SpriteKit cell glyphs. Increase Jersey 10 typography by 10% and use it throughout Pixel Leaderboard, Pet Shop, and Settings surfaces. Light uses its sky gradient without decorative capsule cloud bars; the SpriteKit view must allow transparency so the white rounded board shell, rather than a black scene backing, occupies its corners.

Use the native gameplay composition corresponding to the reviewed PHP design: PimPoPom utility header, Points/Top score and Survived/Lives stat columns, centered color hero with a rounded-square swatch and left-anchored decreasing response bar, a square board up to screen width minus 24 points, and a separate tier-colored Speed streak/multiplier panel above the bottom ad host. Do not visually repeat the active “Tap [color]” instruction below the board; retain that state for accessibility and deterministic automation. Place the gameplay pet at 40% of screen width. In the menu, sleep directional pets after five seconds of inactivity, wake them on interaction, and face them using the original 2-point dead zone and 30-degree half/full-turn boundary. Keep Pet Shop previews static until tapped, keep habitats visible, raise Foka and Misha five points, and use the Pet Shop pink accent for its internal actions.

After the first Arcade Game Over, rotate the exact 26-slogan pool and advance it on tap without an immediate repeat. Use the owner-requested **10-second** native interval; the reviewed web client currently uses five seconds, so this is an intentional native product override rather than accidental drift. Profile, detailed Leaderboard visual restyling, and the real Achievements catalog/claim flow remain outside this batch.

Consequences: Compact-device geometry, non-scrolling behavior, glyph persistence, pet direction/sleep, response-bar drain, StoreKit placeholder safety, and all four theme fixtures are deterministic regression gates. Shops and settings retain native navigation and accessibility rather than copying HTML/CSS or embedding a `WKWebView`. Physical-device timing, listening, and touch validation remain required before release claims.

Revisit when: Dynamic Type or localization cannot fit the fixed menu without an accepted compact adaptation, the parent design deliberately changes, or a new PimPoPom visual system replaces parity as the product goal.

## P-018 — Complete the next native visual-parity and companion pass

- Date: 2026-07-17
- Status: Accepted; slogan, companion, Leaderboard, and result details superseded by P-019

Context: After accepting the fixed-screen native composition, the owner requested a closer translation of the remaining PHP presentation at parent web `main` commit `209ee6ca84b17bc81144d2dc60c613feeae05dc0`. The requested batch adds expressive hit feedback, surface-specific companion placement, a replacement Pancake, stable shop loading, and detailed Leaderboard/Profile/Game Over presentation. It deliberately advances the items that P-017 left for a later batch.

Decision: Show only Perfect and Godlike correct taps as short-lived illuminated bordered stamps containing the same rounded milliseconds used for rating classification. Select from safe anchors around all four board borders and independent tilt presets using presentation-only randomness; never consume deterministic gameplay randomness or alter proof events. Translate the three introductory menu instructions and rotating slogans into the same illuminated visual language. Move the menu pet left by 15% of screen width, move slogans right by 15%, and enlarge slogans by 15%. Apply companion vertical offsets per surface, not globally: raise Foka and Kesha another ten points only in Pet Shop; lower Misha, Tauta, and Pancake ten points only in the main menu. Preserve the original staged 30-degree half/full turn sequence and restart it for every accepted tap, including repeated taps toward the same side. Measure gameplay tap direction against the inner SpriteKit scene rather than the board padding.

Use the owner-supplied Pancake concept as the identity reference for a native ten-frame sprite and replace its bed with a generated glowing blue floor. Retain the unmodified concept, generated sources, alpha masters, deterministic assembly script, runtime assets, hashes, and prompts. Remove the placeholder label and client-side purchase block; price, balance, ownership, purchase, selection, and visibility remain authoritative in the existing PHP catalog and mutations. This approval is for the internal build and does not replace the deferred public-release ownership review.

In Light only, place a subtle white/blue button-like plate behind the wordmark for readability. Keep Theme Shop and Pet Shop content geometrically stable while loading by drawing a modal animated overlay above the existing layout; do not insert loading text into either scroll stack. Rebuild Leaderboard around rank context, current/legacy badges, pet rows, skipped-rank separators, reactions, rating distribution, and verification copy. Rebuild My Profile around signed-out benefits, nickname management, mode-specific rank context, and nearby results using `GET /api/profile?mode=normal|zen`. Rebuild Game Over around top restart/menu controls, a gradient score hero, four primary metrics, reaction distribution, and fixed save/retry status. These are native SwiftUI translations that preserve backend authority and accessibility identifiers, not embedded web views.

Consequences: The native client gains the missing PHP information hierarchy without a schema migration or a second source of account/economy truth. Visual randomness is non-authoritative and deterministic under UI tests. New shared Leaderboard/rating/loading components and retained Pancake sources become regression and asset-validation inputs. Physical iPhone touch, animation, listening, Dynamic Type, VoiceOver, and final public artwork review remain explicit acceptance gates.

Revisit when: Parent visual behavior changes, screen-reader or compact-layout evidence requires a different presentation, backend profile/leaderboard contracts change, or the deferred public-release ownership review rejects or replaces an asset.

## P-019 — Refine native utilities, live ranking presentation, and companion controls

- Date: 2026-07-17
- Status: Accepted

Context: The expanded parity build retained service/version/local-practice explanations in player-facing Leaderboard and Game Over surfaces, used separate Theme action buttons, and still interpreted companion direction with a vertical-angle rule. The owner requested the cleaner current web utility styling, direct theme-tile interaction, exact horizontal pet-facing zones, final surface offsets, and a Game Center connection or placeholder without replacing the existing live backend.

Decision: Keep Hostinger as the only authoritative leaderboard and economy. Public Leaderboard reads remain live. A Google-authenticated player with a confirmed nickname automatically requests an Arcade run ticket and submits the chronological proof at Game Over; anonymous Arcade and all Zen runs remain unranked. Remove the Leaderboard service footer and the persistent result block that described local practice, service, or version. Show only transient saving or upload-failure/retry state. Preserve the ranked ticket, CSRF, build, ruleset, proof-version, abandon, finish, and session-refresh paths.

Use the exact reviewed web coin geometry and colors wherever a visible coin accompanies a balance or price. Give menu coin and rank badges the reviewed black border; show the current signed-in Arcade rank on the trophy. Stack each Leaderboard pet below its place number so nickname and result detail receive the released horizontal space, while keeping the whole result as one coherent accessibility element. Add a clearly non-connecting Game Center placeholder to Profile for the internal alpha. P-011 remains the authority boundary: no GameKit entitlement, identity binding, score mirror, purchase, or economy effect is implied.

Make the complete Theme preview/name tile the select or buy target and remove its nested Select button. A selected tile is disabled and visually selected; an in-flight mutation uses a non-shifting overlay. Give Disco previews an explicit near-black base independently of the active theme. Optically center the six code-native color glyphs in theme previews and the gameplay Your Color swatch. Move the enlarged menu slogan from 15% to 10% right shift, keep the Pet Shop/Theme icons large and leading, and hide the redundant pale hit-rating line below the board while retaining mistakes, accessibility state, and the Perfect/Godlike border stamps.

Companion direction depends only on horizontal distance from the rendered pet center; tap y never affects it. Treat alignment within 0.5 point as front, the first 15% of the active interaction width on either side as half-left/half-right, and farther taps as full-left/full-right. Use full screen width in the menu and gameplay and the 80-point preview width in Pet Shop. Preserve staged wake/turn animation and restart it for each accepted tap. Relative to P-018, move Foka four points down in Pet Shop, move Pancake twenty points down in Pet Shop and the menu, and apply a common ten-point gameplay lift after Pancake's twenty-point downward move, yielding a net ten-point downward Pancake gameplay offset and a ten-point upward offset for every other pet. Offset the whole gameplay companion view so sprite clipping does not undo the placement.

Consequences: The internal alpha presents live ranking and economy state without duplicating technical service copy or creating a second authority. Whole-tile theme interaction and shared web utility assets reduce visual drift. Horizontal pet zones are predictable regardless of tap height. Deterministic unit/API/UI coverage becomes the regression gate for the automatic ranked proof contract, exact thresholds/offsets, direct tile actions, rank badge, Game Center placeholder, hidden duplicate feedback, and clean Leaderboard/results presentation. Real signed-in mutation, Game Center integration, physical touch/listening, accessibility-matrix, and 60/120 Hz validation remain explicit later gates.

Revisit when: Hostinger introduces a native session contract, Game Center is deliberately enabled under P-011, public-release copy requires a verification disclosure elsewhere, measured touch evidence changes the facing zones, or accessibility review requires a different compact row/theme interaction.

## P-020 — Stabilize native theme previews, feedback, and companion poses

- Date: 2026-07-17
- Status: Accepted; supersedes the selected-tile and staged-turn presentation details of P-018/P-019

Context: The owner found that one theme's preview changed when another theme was selected, Pixel preview cells differed from the live board, selected cards became visually dim, recovery feedback was small and duplicated, Disco lacked the intended dance-floor contrast, and companion turns restarted from center instead of continuing from the visible pose. The utility badges, wordmark, Pixel type scale, and life-loss cue also required a final parity pass.

Decision: Treat every Theme Shop preview as a bounded screenshot of its candidate theme. Candidate theme tokens alone determine the board pixels; the currently selected theme may style the surrounding shop screen but cannot recolor or dim that screenshot. Keep a selected tile enabled and guard its tap as a no-op so SwiftUI does not apply disabled opacity. Reuse the same cell geometry, border widths, glyph sizing, corner rules, and candidate-theme colors for Theme Shop, gameplay Your Color, and SpriteKit cells. Anchor the Your Color preview on the left and left-align its name after a fixed gap.

Use the retained Disco concrete, reflected-light, and scratch textures rather than importing the supplied reference photograph. Disco's inactive cell is `#908f8c`, exactly 40% darker per RGB channel than the previous `#f0efea`; inactive borders are dark silver, active borders are light silver, and active colors are the brighter reviewed palette. Increase every Pixel-theme text size by 25%. Darken the green Pim gradient, place coin/rank badges at the lower-right/upper-right button corners, and retain the final net eleven-point inward adjustment for the large Pet Shop and Theme icons.

Remove the Preparing notice. Before every newly started or restarted run, show one centered backlit Get ready announcement for exactly one second and start the deterministic engine only after it disappears. Do not replay it after a non-terminal life loss. Present Too early and Too slow through the same centered announcement layer and suppress their tiny duplicate feedback. Preserve Perfect/Godlike border stamps separately.

Map the five directional sprite poses as full-left, half-left, center, half-right, and full-right. Continue from the currently displayed pose through only adjacent semantic frames, with 100 ms between intermediate poses; for example, half-right to full-right changes one frame and never crosses center. Reserve settle/sleep frames for the five-second menu idle lifecycle and wake directly toward the requested facing. Shop sprites remain static until tapped. A life-losing Arcade mistake emits one `.lifeLoss` event; the Sound FX controller resumes from that same accepted user action before playing the retained `audio-oops.wav` cue. Zen mistakes and non-life-loss events do not play it.

Consequences: Theme tiles are visually stable under every selected-theme combination, the Pixel header matches the live board, Disco contrast is explicit and testable, announcements do not consume gameplay time, pets no longer snap through unrelated poses, and the existing audio provenance remains unchanged. Unit and UI tests lock the color token, candidate-preview isolation, Pixel scale, announcement timing/recovery behavior, all directional pose pairs, selected-card opacity behavior, and life-loss event route. Physical-device listening/touch review, 60/120 Hz timing, VoiceOver/Dynamic Type, and current-batch 13 mini/13 Pro layout validation remain later gates.

Revisit when: A deliberately new theme art direction is accepted, accessibility evidence requires different scaling/contrast, sprite sheets gain additional semantic poses, or physical-device timing/listening reveals a presentation or audio-lifecycle defect.
