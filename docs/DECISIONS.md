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
- Status: Accepted; component naming and reserved-slot sizing refined by P-026

Context: An asynchronously loaded banner can shift the board, intercept reaction taps, overlap safe areas, or create accidental clicks.

Decision: Place the ad container at the absolute bottom of gameplay, below the **Speed Bar** and above the bottom safe-area inset. The bottom order is pet if visible, Speed Bar, separator, reserved ad host, then safe-area inset. Reserve its size before a run. Loading, no-fill, consent, offline state, and removal cannot resize an active board or move a target. Ads never overlay gameplay. The initial recommendation keeps this host empty during an active rapid-tapping run and fills ads only on non-active surfaces until the ad provider's policy and accidental-tap review approve otherwise.

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
- Status: Accepted 2026-07-18; rollout and first-TestFlight scope refined by P-027

Context: Game Center offers familiar leaderboards and achievements but does not understand the server's proof status, economy generation, moderation, or exact-result context.

Decision: Keep the PimPoPom service authoritative and use one **server-fed mirror of protocol-verified Arcade personal-best scores**, not a client-submitted, seasonal, or independent iOS ranking. Reserve the permanent high-to-low integer leaderboard vendor ID `com.otcsoftware.pimpopom.arcade.verified` with player-visible name **Arcade**. The iOS app authenticates `GKLocalPlayer` independently and may obtain Apple's runtime identity-verification signature, but it never submits scores directly. For a normal non-Apple-Arcade game, that signature authenticates `teamPlayerID`, while Apple's server score endpoint requires `gamePlayerID`; merely receiving both values from the client does not prove their association. A future Hostinger design must first establish an Apple-supported trusted mapping protocol, then bind it one-to-one with an authenticated PimPoPom player before a server outbox can submit the player's accepted all-time best. Game Center identity never grants profile ownership, coins, purchases, moderation rights, or authority over the cross-platform leaderboard.

Consequences: Game Center authentication is non-blocking and optional. Cancellation, sign-out, parental controls, network failure, or Apple service failure cannot block local play, PimPoPom/Google login, Hostinger ranking, achievements, shops, or future purchases. Signed `teamPlayerID` material is ephemeral, is never logged or persisted by the current app, and is not sent anywhere yet. The mirror stays disabled until the scoped-ID mapping question, server-side signature verification, one-to-one binding, outbox/idempotency, prerelease handling, and correction policy are resolved. Failed Apple submissions are retryable side effects and do not roll back an accepted PimPoPom result; the outbox coalesces to the latest authoritative all-time best so an older retry cannot lower the mirrored score. A later quarantine or deletion may not fully erase an already mirrored Game Center value, so correction visibility remains required before enabling submissions.

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
- Status: Accepted; build-gate and silent-fallback details superseded by P-024

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
- Status: Accepted; pet-facing detail superseded by P-019 and intro lifecycle superseded by P-024

Context: The scrollable floating web dialog was appropriate for a browser but made the native app feel like a restyled port. The owner requested a fixed main menu, closer gameplay chrome, repaired pet behavior, and specific Light/Pixel corrections while retaining the current rules and shared backend. Parent SpeedyTapper commit `209ee6ca84b17bc81144d2dc60c613feeae05dc0` adds the current menu-slogan pool and rotation behavior.

Decision: Keep the main menu inside the device safe area without a `ScrollView` or floating dialog panel; feature catalogs and settings may scroll where their content requires it. Remove build, backend, and season diagnostics from the menu footer. Keep Remove Ads at lower right and route it to a no-entitlement StoreKit placeholder. Add one persisted Glyphs preference that controls theme previews, the target header, feedback copy, and SpriteKit cell glyphs. Increase Jersey 10 typography by 10% and use it throughout Pixel Leaderboard, Pet Shop, and Settings surfaces. Light uses its sky gradient without decorative capsule cloud bars; the SpriteKit view must allow transparency so the white rounded board shell, rather than a black scene backing, occupies its corners.

Use the native gameplay composition corresponding to the reviewed PHP design: PimPoPom utility header, Points/Top score and Survived/Lives stat columns, centered color hero with a rounded-square swatch and left-anchored decreasing response bar, a square board up to screen width minus 24 points, and a separate tier-colored Speed streak/multiplier panel above the bottom ad host. Do not visually repeat the active “Tap [color]” instruction below the board; retain that state for accessibility and deterministic automation. Place the gameplay pet at 40% of screen width. In the menu, sleep directional pets after five seconds of inactivity, wake them on interaction, and face them using the original 2-point dead zone and 30-degree half/full-turn boundary. Keep Pet Shop previews static until tapped, keep habitats visible, raise Foka and Misha five points, and use the Pet Shop pink accent for its internal actions.

After the first Arcade Game Over, rotate the exact 26-slogan pool and advance it on tap without an immediate repeat. Use the owner-requested **10-second** native interval; the reviewed web client currently uses five seconds, so this is an intentional native product override rather than accidental drift. Profile, detailed Leaderboard visual restyling, and the real Achievements catalog/claim flow remain outside this batch.

Consequences: Compact-device geometry, non-scrolling behavior, glyph persistence, pet direction/sleep, response-bar drain, StoreKit placeholder safety, and all four theme fixtures are deterministic regression gates. Shops and settings retain native navigation and accessibility rather than copying HTML/CSS or embedding a `WKWebView`. Physical-device timing, listening, and touch validation remain required before release claims.

Revisit when: Dynamic Type or localization cannot fit the fixed menu without an accepted compact adaptation, the parent design deliberately changes, or a new PimPoPom visual system replaces parity as the product goal.

## P-018 — Complete the next native visual-parity and companion pass

- Date: 2026-07-17
- Status: Accepted; slogan, companion, Leaderboard, and result details superseded by P-019; reaction-feedback scope superseded by P-026

Context: After accepting the fixed-screen native composition, the owner requested a closer translation of the remaining PHP presentation at parent web `main` commit `209ee6ca84b17bc81144d2dc60c613feeae05dc0`. The requested batch adds expressive hit feedback, surface-specific companion placement, a replacement Pancake, stable shop loading, and detailed Leaderboard/Profile/Game Over presentation. It deliberately advances the items that P-017 left for a later batch.

Decision: Show only Perfect and Godlike correct taps as short-lived illuminated bordered stamps containing the same rounded milliseconds used for rating classification. Select from safe anchors around all four board borders and independent tilt presets using presentation-only randomness; never consume deterministic gameplay randomness or alter proof events. Translate the three introductory menu instructions and rotating slogans into the same illuminated visual language. Move the menu pet left by 15% of screen width, move slogans right by 15%, and enlarge slogans by 15%. Apply companion vertical offsets per surface, not globally: raise Foka and Kesha another ten points only in Pet Shop; lower Misha, Tauta, and Pancake ten points only in the main menu. Preserve the original staged 30-degree half/full turn sequence and restart it for every accepted tap, including repeated taps toward the same side. Measure gameplay tap direction against the inner SpriteKit scene rather than the board padding.

Use the owner-supplied Pancake concept as the identity reference for a native ten-frame sprite and replace its bed with a generated glowing blue floor. Retain the unmodified concept, generated sources, alpha masters, deterministic assembly script, runtime assets, hashes, and prompts. Remove the placeholder label and client-side purchase block; price, balance, ownership, purchase, selection, and visibility remain authoritative in the existing PHP catalog and mutations. This approval is for the internal build and does not replace the deferred public-release ownership review.

In Light only, place a subtle white/blue button-like plate behind the wordmark for readability. Keep Theme Shop and Pet Shop content geometrically stable while loading by drawing a modal animated overlay above the existing layout; do not insert loading text into either scroll stack. Rebuild Leaderboard around rank context, current/legacy badges, pet rows, skipped-rank separators, reactions, rating distribution, and verification copy. Rebuild My Profile around signed-out benefits, nickname management, mode-specific rank context, and nearby results using `GET /api/profile?mode=normal|zen`. Rebuild Game Over around top restart/menu controls, a gradient score hero, four primary metrics, reaction distribution, and fixed save/retry status. These are native SwiftUI translations that preserve backend authority and accessibility identifiers, not embedded web views.

Consequences: The native client gains the missing PHP information hierarchy without a schema migration or a second source of account/economy truth. Visual randomness is non-authoritative and deterministic under UI tests. New shared Leaderboard/rating/loading components and retained Pancake sources become regression and asset-validation inputs. Physical iPhone touch, animation, listening, Dynamic Type, VoiceOver, and final public artwork review remain explicit acceptance gates.

Revisit when: Parent visual behavior changes, screen-reader or compact-layout evidence requires a different presentation, backend profile/leaderboard contracts change, or the deferred public-release ownership review rejects or replaces an asset.

## P-019 — Refine native utilities, live ranking presentation, and companion controls

- Date: 2026-07-17
- Status: Accepted; Game Center placeholder detail superseded by P-027

Context: The expanded parity build retained service/version/local-practice explanations in player-facing Leaderboard and Game Over surfaces, used separate Theme action buttons, and still interpreted companion direction with a vertical-angle rule. The owner requested the cleaner current web utility styling, direct theme-tile interaction, exact horizontal pet-facing zones, final surface offsets, and a Game Center connection or placeholder without replacing the existing live backend.

Decision: Keep Hostinger as the only authoritative leaderboard and economy. Public Leaderboard reads remain live. A Google-authenticated player with a confirmed nickname automatically requests an Arcade run ticket and submits the chronological proof at Game Over; anonymous Arcade and all Zen runs remain unranked. Remove the Leaderboard service footer and the persistent result block that described local practice, service, or version. Show only transient saving or upload-failure/retry state. Preserve the ranked ticket, CSRF, build, ruleset, proof-version, abandon, finish, and session-refresh paths.

Use the exact reviewed web coin geometry and colors wherever a visible coin accompanies a balance or price. Give menu coin and rank badges the reviewed black border; show the current signed-in Arcade rank on the trophy. Stack each Leaderboard pet below its place number so nickname and result detail receive the released horizontal space, while keeping the whole result as one coherent accessibility element. The original internal-alpha Game Center placeholder was intentionally non-connecting; P-027 later replaces it with optional GameKit authentication while P-011 keeps Hostinger authoritative and still forbids client score/economy effects.

Make the complete Theme preview/name tile the select or buy target and remove its nested Select button. A selected tile is disabled and visually selected; an in-flight mutation uses a non-shifting overlay. Give Disco previews an explicit near-black base independently of the active theme. Optically center the six code-native color glyphs in theme previews and the gameplay Your Color swatch. Move the enlarged menu slogan from 15% to 10% right shift, keep the Pet Shop/Theme icons large and leading, and hide the redundant pale hit-rating line below the board while retaining mistakes, accessibility state, and the Perfect/Godlike border stamps.

Companion direction depends only on horizontal distance from the rendered pet center; tap y never affects it. Treat alignment within 0.5 point as front, the first 15% of the active interaction width on either side as half-left/half-right, and farther taps as full-left/full-right. Use full screen width in the menu and gameplay and the 80-point preview width in Pet Shop. Preserve staged wake/turn animation and restart it for each accepted tap. Relative to P-018, move Foka four points down in Pet Shop, move Pancake twenty points down in Pet Shop and the menu, and apply a common ten-point gameplay lift after Pancake's twenty-point downward move, yielding a net ten-point downward Pancake gameplay offset and a ten-point upward offset for every other pet. Offset the whole gameplay companion view so sprite clipping does not undo the placement.

Consequences: The internal alpha presents live ranking and economy state without duplicating technical service copy or creating a second authority. Whole-tile theme interaction and shared web utility assets reduce visual drift. Horizontal pet zones are predictable regardless of tap height. Deterministic unit/API/UI coverage becomes the regression gate for the automatic ranked proof contract, exact thresholds/offsets, direct tile actions, rank badge, Game Center placeholder, hidden duplicate feedback, and clean Leaderboard/results presentation. Real signed-in mutation, Game Center integration, physical touch/listening, accessibility-matrix, and 60/120 Hz validation remain explicit later gates.

Revisit when: Hostinger introduces a native session contract, Game Center is deliberately enabled under P-011, public-release copy requires a verification disclosure elsewhere, measured touch evidence changes the facing zones, or accessibility review requires a different compact row/theme interaction.

## P-020 — Stabilize native theme previews, feedback, and companion poses

- Date: 2026-07-17
- Status: Accepted; supersedes the selected-tile and staged-turn presentation details of P-018/P-019; mistake copy and Disco contrast refined by P-024; feedback formatting/motion superseded by P-026

Context: The owner found that one theme's preview changed when another theme was selected, Pixel preview cells differed from the live board, selected cards became visually dim, recovery feedback was small and duplicated, Disco lacked the intended dance-floor contrast, and companion turns restarted from center instead of continuing from the visible pose. The utility badges, wordmark, Pixel type scale, and life-loss cue also required a final parity pass.

Decision: Treat every Theme Shop preview as a bounded screenshot of its candidate theme. Candidate theme tokens alone determine the board pixels; the currently selected theme may style the surrounding shop screen but cannot recolor or dim that screenshot. Keep a selected tile enabled and guard its tap as a no-op so SwiftUI does not apply disabled opacity. Reuse the same cell geometry, border widths, glyph sizing, corner rules, and candidate-theme colors for Theme Shop, gameplay Your Color, and SpriteKit cells. Anchor the Your Color preview on the left and left-align its name after a fixed gap.

Use the retained Disco concrete, reflected-light, and scratch textures rather than importing the supplied reference photograph. Disco's inactive cell is `#908f8c`, exactly 40% darker per RGB channel than the previous `#f0efea`; inactive borders are dark silver, active borders are light silver, and active colors are the brighter reviewed palette. Increase every Pixel-theme text size by 25%. Darken the green Pim gradient, place coin/rank badges at the lower-right/upper-right button corners, and retain the final net eleven-point inward adjustment for the large Pet Shop and Theme icons.

Remove the Preparing notice. Before every newly started or restarted run, show one centered backlit Get ready announcement for exactly one second and start the deterministic engine only after it disappears. Do not replay it after a non-terminal life loss. Present Too early and Too slow through the same centered announcement layer and suppress their tiny duplicate feedback. Preserve Perfect/Godlike border stamps separately.

Map the five directional sprite poses as full-left, half-left, center, half-right, and full-right. Continue from the currently displayed pose through only adjacent semantic frames, with 100 ms between intermediate poses; for example, half-right to full-right changes one frame and never crosses center. Reserve settle/sleep frames for the five-second menu idle lifecycle and wake directly toward the requested facing. Shop sprites remain static until tapped. A life-losing Arcade mistake emits one `.lifeLoss` event; the Sound FX controller resumes from that same accepted user action before playing the retained `audio-oops.wav` cue. Zen mistakes and non-life-loss events do not play it.

Consequences: Theme tiles are visually stable under every selected-theme combination, the Pixel header matches the live board, Disco contrast is explicit and testable, announcements do not consume gameplay time, pets no longer snap through unrelated poses, and the existing audio provenance remains unchanged. Unit and UI tests lock the color token, candidate-preview isolation, Pixel scale, announcement timing/recovery behavior, all directional pose pairs, selected-card opacity behavior, and life-loss event route. Physical-device listening/touch review, 60/120 Hz timing, VoiceOver/Dynamic Type, and current-batch 13 mini/13 Pro layout validation remain later gates.

Revisit when: A deliberately new theme art direction is accepted, accessibility evidence requires different scaling/contrast, sprite sheets gain additional semantic poses, or physical-device timing/listening reveals a presentation or audio-lifecycle defect.

## P-021 — Canonical cell artwork and shared companion tap following

- Date: 2026-07-17
- Status: Accepted; supersedes the cell-material, badge-compositing, and companion-input presentation details of P-020; board-gap gameplay handling superseded by P-026

Context: Final Simulator inspection found that Unicode glyph metrics produced unequal live-cell sizes, the candidate previews could still drift from SpriteKit material rendering, active Disco cells needed substantially more light, Light and Pixel lacked their requested surface character, a button border could show through the coin count, and menu/gameplay did not reliably receive the same companion-facing input as Pet Shop. Pancake also required a surface-specific vertical correction and a clean replacement for its artifacted full-left frame.

Decision: Define all six glyphs as normalized code-native geometry inside one canonical square and use it for live SpriteKit cells, Theme Shop screenshots, and Your Color. Smooth themes use normalized vector paths; Pixel uses matching 9×9 masks with exact cell division so every glyph fills the same declared box at every supported size. Keep hit regions and gameplay rules independent of visual material. Light adds a clipped crystal/glass gradient and specular highlight. Pixel adds a faint deterministic, nearest-neighbor, clipped grain texture and pixel glyph paths. Disco preserves the darker uneven inactive floor but uses vivid saturated active colors, a bright backlight, scratch texture, and light-silver active border. Cache code-native SpriteKit textures where practical and redraw only one top border after Pixel compositing.

Compose coin and rank badges as opaque outer overlays after the underlying button style so neither a translucent fill nor a lower stacking order can expose the button border through the value. Preserve the lower-right coin and upper-right rank corners.

Use one horizontal `PetTapFollow` resolver for Pet Shop, menu, and gameplay. Derive direction from the rendered pet center in the surface's named coordinate space and advance only through adjacent semantic poses from the currently visible frame. Every touch inside the gameplay board, including a visual gap between cells, may update companion facing; only an actual cell hit is forwarded to the deterministic engine, so this presentation behavior cannot create or suppress a game action. Lower Pancake fifteen points relative to its floor on the main menu and Leaderboard only; leave its gameplay and Pet Shop placement unchanged by this adjustment. Use the clean full-right Pancake sprite mirrored for semantic full-left rather than displaying the artifacted source frame.

Consequences: Glyph proportions, preview/live materials, and companion direction have one implementation contract instead of three similar render/input paths. Deterministic unit tests cover every glyph, scale, style, effect token, tap zone, board-gap route, Pancake offset, and mirror rule; XCUITest covers menu/gameplay following and Pancake placement. These are presentation changes only. Physical-device touch, 60/120 Hz timing, VoiceOver/Dynamic Type, performance profiling, and current-batch 13 mini/13 Pro layout validation remain later gates.

Revisit when: A theme deliberately adopts a non-canonical glyph language, new pet sheets supply corrected directional art, performance evidence requires pre-rendered material assets, or physical-device input testing exposes a coordinate-space mismatch.

## P-022 — Port server-authoritative achievements and refine canonical cells

- Date: 2026-07-18
- Status: Accepted; supersedes the Achievements-placeholder scope in P-016/P-017 and refines the cell presentation in P-021; visible-balance detail superseded by P-024; Disco underlay detail superseded by P-026

Context: The existing PHP service already exposes five achievement goals, unlock state, idempotent reward claims, and the authoritative earned-coin balance. PimPoPom still showed a placeholder, while the current canonical cell renderer left a hole where two smooth cross paths overlapped, muted active Disco colors, exposed nonblack corners around rounded Disco tiles, and made Pixel grain too faint to read as brighter squares.

Decision: Reuse the deployed compatibility contract for the internal alpha. `GET /api/achievements` is a public catalog/state read. `POST /api/achievements/claim` is an authenticated CSRF mutation with the exact body `{"id":"<stable-id>"}`; HTTP 201 is the first claim and HTTP 200 is an idempotent duplicate. The server-returned catalog, locked/claimable/claimed state, reward, count, and `coinBalance` are authoritative. A bundled five-item catalog exists only for signed-out/error presentation and cannot unlock an item, grant coins, or override a response. Serialize claims with the existing session/player mutation generation, reject stale account responses, refresh an expired session or CSRF token, and update local profile coins only from a validated server response. Describe `coinsEarned` as credited because server-side debt may absorb some or all of the nominal reward.

Present the catalog through one theme-aware native Achievements surface with progress, authoritative balance, locked/ready/claimed cards, a signed-out Profile route, and a main-menu marker when a reward is ready. Refresh after session changes, eligible game return, and a new pet purchase. This does not enable StoreKit, ads, Game Center authority, or a new persistence contract.

Use one non-overlapping outline for the smooth cross so its center remains filled under winding and even-odd rules. Keep Disco's retained texture language but use the accepted high-saturation active tokens, restrained white wash, same-color additive light, and an opaque black square below every rounded cell so the exposed corner areas are black. Render Pixel grain as deterministic clipped 32-grid squares, biased toward subtle brighter samples, identically in SpriteKit cells and SwiftUI previews.

Consequences: PimPoPom can display and claim the same earned rewards as the PHP version without duplicating economy truth. Unit and UI tests cover the exact routes/body/CSRF, malformed and stale responses, session expiry, the five stable fallback IDs/rewards, an offline 9-to-10 coin claim, solid cross center, Disco color/corner layering, and Pixel sample geometry. Real authenticated Hostinger claim, physical-device visual/touch review, 13 mini/13 Pro reruns, and the accessibility matrix remain explicit validation gates.

Revisit when: the versioned native API replaces the compatibility routes, the server catalog/schema changes, StoreKit or Game Center is deliberately connected, or physical/accessibility evidence requires another presentation treatment.

## P-023 — Use native selectable icons with a direct Home Screen shortcut

- Date: 2026-07-18
- Status: Accepted; refines the app-icon system in P-009

Context: The owner selected the glowing stacked `Pim` / `Po` / `Pom` artwork as the default, requested theme-specific Light and Pixel options, removed the black-outline candidate from the app, and asked for Telegram-style access to icon selection from the Home Screen context menu.

Decision: Ship ImageGen Glow as the primary asset-catalog icon and Light glass plus Pixel as alternate icon sets. Treat `UIApplication.alternateIconName` as the current value and change it only through `setAlternateIconName`; `nil` always restores Glow, while iOS owns persistence and confirmation. Do not bundle the retired black-outline candidate, but retain its source, renderer, prompt, and hashes for provenance and rollback.

Expose the same three whole-tile choices in Settings. Register one static Home Screen quick action titled **Change Icon**. Its stable internal route is `pimpopom://settings/icon`; both shortcut-item delivery and custom-URL delivery open the icon selector during cold or warm app activation. The shortcut grants no account, purchase, economy, or gameplay state.

Consequences: XcodeGen declares only Light and Pixel as alternates, the compiled app metadata becomes a regression-checked contract, and a long press can reach icon selection without navigating the menu. Runtime/master equality, opacity, dimensions, catalogs, previews, prompts, and hashes are validated together. Physical Home Screen masks, actual icon switching, Spotlight/Settings/notification appearances, tinted icon behavior, localization, and accessibility remain device QA gates.

Revisit when: final brand testing selects different artwork, Apple changes alternate-icon or quick-action behavior, localization requires dynamic shortcut registration, or a future theme earns its own icon.

## P-024 — Keep ranked compatibility explicit and finish the current gameplay polish

- Date: 2026-07-18
- Status: Accepted; refines P-014, P-017, P-020, and P-022; build-gate and display-name details refined by P-025; feedback and Disco layers superseded by P-026

Context: The live Hostinger deployment advanced its proof build gate from `20260715-1` to `20260716-1`, while the native client still sent the retired value and swallowed the resulting ranked-ticket failure. Consequently a signed-in Arcade game could run without a ticket and never submit a result. The owner also found that the Leaderboard score column collapsed on the SE, asked to remove the Legacy badge and Achievements wallet display, consolidated early/wrong-cell copy, requested stronger Disco contrast and feedback layering, required the first three rules once per app launch, and selected `com.otcsoftware.pimpopom` as the app bundle identifier.

Decision: Keep the owner-only PHP compatibility exception current at the live `20260716-1` build, `reaction-proof-v2` ruleset, and proof version 1. Arcade must bootstrap the PHP session before play; a Google-authenticated player with a confirmed nickname must also obtain a PHP run ticket. A session or ticket error presents a blocking retry/menu state and never silently becomes an unsaved practice run. Submit the native engine's chronological integer proof at Game Over. Accept a `verified` finish only when its `submittedEntryId` exactly equals the ticket `runId`; treat `review` and `quarantined` as persisted but withheld and say so. Keep public and Profile leaderboard reads on the existing `/api/leaderboard` and `/api/profile` routes. Reserve a fixed trailing score column in every Leaderboard row and remove the player-facing Legacy badge without changing stored verification data.

Keep achievement catalog, claim response, and wallet reconciliation server-authoritative, but omit the current balance from the Achievements screen. Map both pre-target/empty and wrong-cell life losses to one centered **Missed** announcement; retain **Too slow** for late expiry and the existing loss cue. Render Perfect/Godlike stamps plus visible Great/Good feedback above SpriteKit and every board refresh. Give the Your Color panel a three-point outline. Make menu onboarding launch-local: show the three rule stamps after every cold app launch, then switch to the 10-second slogan pool after the first completed Arcade or Zen game of that process; never persist this switch across launches.

For Disco, use near-black inactive cells, dark-silver inactive borders, stronger same-color additive target glow, retained scratch wear, and a visibly black concrete field with cyan/magenta/amber light reflections behind gameplay/header chrome. Preserve the opaque black square under each rounded cell from P-022 so its exposed corner areas remain black. Use `com.otcsoftware.pimpopom` for the app and matching test identifiers. Automatic signing may register this as a new app, and Google Sign-In requires an iOS OAuth client created for this exact bundle; the retired alpha OAuth client is not reusable as proof of matching configuration.

Consequences: New verified native scores can again pass the deployed PHP build gate and obtain exact ranked context, while network/build mismatches are visible before play. The SE Leaderboard cannot compress away scores. Old verification records remain intact but no longer add a Legacy chip to the compact row. Onboarding repeats predictably per launch without altering persistent audio/theme/glyph preferences. The bundle change installs as a different app identity from earlier physical checkpoints and may reset app-local state; server players, coins, and ranks remain associated through the same successfully verified Google account. Focused unit/UI tests cover request metadata, genuine engine proof opcodes, finish confirmation, row score visibility, hidden Achievements balance, launch-local onboarding, feedback copy/layers, and Disco presentation. A real authenticated Hostinger finish and physical-device OAuth/signing validation remain required before claiming end-to-end write validation.

Revisit when: Hostinger changes its accepted build/ruleset/proof contract, a versioned native API replaces the compatibility exception, a real device exposes an OAuth/signing migration issue, or accessibility/physical visual evidence requires another compact presentation adjustment.

## P-025 — Follow the 20260718 proof gate and preserve rounded Disco compositing

- Date: 2026-07-18
- Status: Accepted; refines the current compatibility and presentation details in P-024; rounded Disco compositing superseded by P-026

Context: The deployed PHP service advanced its exact ranked-run build gate to `20260718-1` and added an `achievementSnapshot` field to session and finish responses without changing cookies, CSRF, proof events, score submission, or finish semantics. The installed iOS build still advertised itself as **PimPoPom Alpha**. Owner-supplied 1×1 and 2×2 Disco screenshots also exposed a square colored frame around rounded active tiles: the opaque square corner base was composited above the expanded rounded glow and clipped that glow at the rectangular cell bounds.

Decision: Send `20260718-1` when requesting a ranked ticket, then echo that server-issued ticket's build ID in the finish payload while retaining `reaction-proof-v2`, proof version 1, the existing secure-cookie/CSRF lifecycle, and chronological integer events. Keep `/api/leaderboard` for native Leaderboard reads because it still works and includes the total/rank/context fields that the simpler `/api/top-scores` response omits. Continue using synthesized `Codable` models with the default `JSONDecoder`, which ignores unknown response keys; regression-decode both session and finish payloads containing `achievementSnapshot`.

Set `CFBundleDisplayName` to **PimPoPom** while retaining `CFBundleName`, product name, and bundle identifier `com.otcsoftware.pimpopom`. For Disco cells, preserve an opaque black square as the base below every rounded cell, but composite the rounded active backlight above that base and below the cell. Clip the halo to a narrow 1.2-percent expanded rounded contour, leaving the true square corners on the opaque black base. Apply the same base → clipped glow → cell order to SpriteKit gameplay and SwiftUI previews. The rounded light can feather naturally without being cut into a square outline or filling the four corner wedges.

Consequences: Ranked iOS starts match the currently deployed PHP gate, additive response fields remain forward-compatible, and existing Leaderboard context is preserved. Home Screen, Spotlight, and system UI receive the final product name on the next install. Disco's tile geometry remains unchanged for gameplay/hit testing, but its bounded corner lighting follows the rounded tile instead of the rectangular cell frame. Tests lock the exact build ID, unknown-key decoding, compiled bundle metadata, halo bound, and `corner base < rounded glow < cell` layer order. A real authenticated ranked write and final physical visual review remain explicit validation steps.

Revisit when: Hostinger advances the accepted build/ruleset/proof contract, the native client adopts a versioned API or top-score-only surface, Apple identity metadata changes, or physical-device review requires a stricter no-spill Disco glow mask.

## P-026 — Rebuild Disco feedback and finish gameplay-footer polish

- Date: 2026-07-18
- Status: Accepted; supersedes the Perfect-only feedback scope in P-018/P-020, the presentation-only board-gap rule in P-021, and the opaque-square/bounded-glow Disco compositing in P-022/P-024/P-025; refines P-007

Context: The bounded Disco implementation still exposed mismatched radii and a rectangular ghost under the game-zone corner. It also treated inter-cell taps as dead input, refreshed the board over reaction labels, and lacked tap-local score feedback. The owner then requested compact lowercase millisecond copy, rating-specific Speed Bar motion, a semantic Zen Any preview, red life symbols, the final Speed Bar name, and a standard banner placeholder without sacrificing the established near-full-width SE board.

Decision: Use one shared 12-point board inset for SpriteKit and SwiftUI. Smooth live-cell radii follow the parent-web clamp `max(11, min(22, 30 / gridDimension))`, yielding 22, 15, and 11 points for 1×1, 2×2, and 4×4; the smooth shell uses 22 points and Pixel remains square. Independently clip the SpriteKit scene and Disco halo to that same shell, then draw one final shell stroke. Never render an opaque square below a rounded cell. Preserve the retained web material palette, mixed active border, scratch/glaze/depth textures, and continuous concrete backing. Draw a cached, prewarmed, transparent-center Core Graphics halo with `.plusLighter` above active cells but below the shell border and every feedback layer; target and halo expire together.

Every accepted hit publishes the displayed rounded milliseconds, authoritative multiplied `pointsAwarded`, rating, and tap location without changing proof or score rules. Format the stamp as `Rating - Nms`. Reaction stamps use transparent interiors with glowing text and borders; centered Get ready/Missed/Too slow announcements retain their readability backing. Draw the grouped score (for example `+2,343 points`) without a capsule, border, or opaque backing, starting 15 points above the tap. Capture the board, Points field, and Speed Bar frames when that hit presentation is created. The score follows one direct segment into the Points field while shrinking and dissolving. Great and Good stay on their randomized border lane. Godlike and Perfect shrink along a separate direct, monotonic segment into the captured Speed Bar destination while its presented fill advances, then disappear there. Never recompute either destination from a refreshed board while an effect is moving. Keep up to eight independent presentations so rapid accepted taps do not cancel one another.

A touch inside the playable board frame but between cell paths maps to a valid cell. While a target is active, exclude that target from the mapping so the action becomes a proof-valid wrong-cell miss; while waiting, map to an empty-board miss. Arcade applies its normal life loss and `oops` cue, while Zen retains its no-life-loss invariant. The outer 12-point shell padding remains ignored.

Replace Zen's yin-yang emoji with a normal 40-point, glyph-free Any cell using the same left-to-right green/yellow/orange/pink/purple/blue progression as the PimPoPom wordmark. Use `#ff5370` for Arcade hearts and Zen infinity. Give the Your Color panel a five-point outline plus two outward glow passes; this supersedes P-024's three-point outline. Rename the visible and accessibility component to **Speed Bar**. Lift the combined pet/bar footer by eight points, allow the pet to overlap above its fixed 50-point bar slot, and reserve a 50-point disabled banner host below it. This keeps the pet and meter higher while preserving the 351-point near-full-width SE board.

For Foka only, render semantic half-right from a horizontal mirror of the reviewed half-left source cell and semantic full-right from a mirror of the reviewed full-left source cell. Keep the semantic frame sequence intact so animation still advances from its current pose through adjacent directions. Do not alter the source sheet or the rendering policy of any other pet.

Consequences: Disco has matching shell/cell curves, continuous concrete corners, and outward additive light without square ghosts. Gap taps can no longer vanish outside the proof stream. Feedback remains presentation-only but now explains both awarded points and multiplier progress without opaque flyout furniture or target drift. Zen and footer semantics are stable across themes, and the standard banner reservation does not resize the reaction board. Foka's turn is visually symmetric without a second asset fork. Deterministic tests lock radius/layout geometry, halo alpha/cache/layers, expiry synchronization, proof-valid gap misses and loss audio, authoritative feedback payloads, exact copy, direct clamped motion, captured HUD destinations, Zen gradient tokens, the five-point glowing frame, Foka-only mirrors, red HUD color, footer lift, banner height, and compact-device board width. Physical touch/audio, Reduce Motion, 60/120 Hz pacing, current 13 mini/13 Pro layout, and authenticated Hostinger writes remain later gates.

Revisit when: A real ad SDK defines an adaptive size contract, Reduce Motion review requires a non-flying equivalent, physical frame pacing exposes feedback timing cost, the parent web material changes deliberately, or the proof protocol adds a first-class board-gap coordinate event.

## P-027 — Start named TestFlight QA and enable optional Game Center authentication

- Date: 2026-07-18
- Status: Accepted; narrow exception to P-014/P-025 for the named first beta cohort; launch-time authentication superseded by P-041

Context: The owner enrolled in the Apple Developer Program, created the PimPoPom App Store Connect record for `com.otcsoftware.pimpopom`, requested a first internal tester plus one external QA tester, and accepted P-011. A separate native staging backend does not yet exist, while the current app already uses the deployed Hostinger compatibility service and shared Season 1 data. Ads and StoreKit remain non-granting placeholders.

Decision: Create a release-optimized **Staging** Xcode configuration and upload a clean `1.0` TestFlight candidate without the TestFlight-internal-only restriction, so one processed build can serve both groups. Limit this exception to direct email invitations for the owner and the single named external QA tester; do not create a public link or broaden the cohort. TestFlight review notes must disclose that this is a narrow production-compatible technical beta using the existing Hostinger service and real shared player/ranking data, with Ads and StoreKit disabled placeholders. This exception does not convert the compatibility PHP contract into the production native architecture and does not authorize an App Store release.

Enable the Game Center capability and Boolean entitlement for `com.otcsoftware.pimpopom`. Install `GKLocalPlayer.local.authenticateHandler` during launch without awaiting it, present Apple's supplied sign-in controller when necessary, and expose truthful connected/unavailable state plus user-triggered retry in Profile. Deterministic automated tests suppress system authentication. Show both scoped identifiers only as runtime connection state, but model Apple's verification tuple specifically around its signed `teamPlayerID`; do not claim that it proves `gamePlayerID`, send it to Hostinger, or add a client score-submission path. Configure the one permanent Arcade leaderboard in App Store Connect, but keep it empty until the verified server mirror is implemented and validated.

Consequences: Internal and external TestFlight processing/review can begin while engineering continues, but this cohort touches the live compatibility service and must avoid destructive economy/profile experiments. Apple Beta App Review is asynchronous and is not complete merely because a build was submitted. The existing Google OAuth configuration must still match the final bundle identifier on a real TestFlight install. Game Center failure has no effect outside the optional Profile status. Public beta expansion, App Store submission, live ads, StoreKit value, and the server-fed leaderboard mirror remain blocked on their dedicated contracts and review gates.

Revisit when: the named QA cohort expands, a separate staging backend becomes available, Apple rejects the compatibility/login design, the server identity-binding/outbox path is implemented, or an App Store production candidate is prepared.

## P-028 — Keep reaction feedback local and reduce glyph prominence

- Date: 2026-07-18
- Status: Accepted; supersedes P-026 only for feedback placement/motion, Your Color outline width, and glyph scale; advances the named TestFlight candidate in P-027

Context: Capturing the Points and Speed Bar frames made correct-hit feedback travel away from the physical tap, while the canonical glyph box remained visually dominant inside the tiles. The owner requested one simpler local gesture language and a smaller target-panel frame for the next cable and TestFlight build.

Decision: Keep authoritative score, rating, and rounded reaction timing unchanged. Show grouped `+N points` copy 20 points left and 20 points above the accepted tap, rotated 40 degrees counterclockwise. Show every Godlike, Perfect, Great, and Good stamp 30 points right and 30 points above that tap, rotated 40 degrees clockwise. Keep both interiors transparent, allow up to eight independent tap presentations, hold them in place, and fade both completely within 980 milliseconds. Do not measure or capture HUD destinations, move score copy into the Points field, or feed Godlike/Perfect stamps into the Speed Bar.

Reduce the shared canonical glyph box by dividing its existing resolved size—including the preview and live-cell minimum—by 2.5. This applies identically to smooth and Pixel paths in live cells, Your Color, and theme previews without changing glyph shape or color-blind semantics. Reduce the glowing Your Color outline from five to four points while retaining both outward glow passes. Advance the staging/TestFlight identity to marketing version `1.01`, build `2`; this remains a TestFlight update, not an App Store release.

Consequences: Tap feedback stays spatially tied to the player's action and cannot collide with or animate toward the HUD/footer. Every theme continues to share one equal-bounds glyph contract at the smaller scale. Tests lock the exact offsets, rotations, 980-millisecond lifetime, no-destination presentation model, glyph divisor, outline width, and staging version/build. Physical review must confirm that the reduced Pixel glyphs remain readable and that edge-adjacent feedback is acceptably visible.

Revisit when: physical-device legibility requires a less aggressive minimum glyph size, Reduce Motion needs a separate transition, or the feedback offsets collide with a future board layout.

## P-029 — Scale glyphs by board density and unify local tap feedback

- Date: 2026-07-19
- Status: Accepted; supersedes P-028 for glyph scale, successful-hit composition, reaction copy, and main-menu optical offsets

Context: Physical review of the reduced P-028 glyphs found that one uniform scale made dense boards and compact previews too timid while the one-cell board was already balanced. The separated, tilted points and reaction labels also created more visual language than one accepted tap needed. Light's fixed blue Your Color outline could disagree with the selected cell, and the launch rules, rotating slogans, and pet needed small independent horizontal corrections.

Decision: Retain the normalized equal-bounds glyph geometry and P-028's reduced base box. Keep that box at 1× on the 1×1 board, multiply it by 2 on the 2×2 board, and by 3 on the 4×4 board (the 16-cell stage). Use the same 3× multiplier in the Arcade Your Color swatch and every Theme Shop screenshot. Do not change hit regions, difficulty timing, target selection, glyph semantics, or the Zen gradient swatch. In Arcade, derive the Your Color panel outline and glow from the selected cell color; Light no longer substitutes a fixed blue outline.

For each accepted tap, show one borderless, unrotated two-line presentation at the normalized tap coordinate: 16-point `+N points` copy and a smaller 12-point `Rating • Nms` line 19 points below it. Fade the grouped copy together after a 680-millisecond hold and remove it at 980 milliseconds; do not animate it toward the Points field or Speed Bar. Continue allowing up to eight concurrent presentations. Render the centered **Missed** announcement with each theme's true yellow cell color. Move the cold-launch rule group 10 points right, rotating slogans 10 points left, and the rendered menu pet plus its tap-follow center 10 points right.

Consequences: Glyph visibility now grows with board density without disturbing the already accepted one-cell composition, and preview surfaces remain representative of the most demanding live stage. A correct tap has one stable visual anchor and one fade lifecycle rather than two decorated stamps. Light's target panel cannot advertise a color different from its actual cell. Deterministic tests lock all scale factors, exact tap/rating positions, copy, timing, yellow Missed mapping, menu offsets, and the menu pet input/render alignment. This batch is merged without a build-number change or TestFlight/App Store upload. A later owner instruction authorizes a direct development-signed cable install; install/launch alone is not visual acceptance, so structured physical review remains required.

Revisit when: physical-device review shows edge clipping, the 4×4 glyphs crowd their cell material, Dynamic Type requires a separate feedback layout, or a future board dimension needs an explicit scale contract.

## P-030 — Reduce preview and dense-board glyphs

- Date: 2026-07-19
- Status: Accepted; supersedes P-029 for the Arcade Your Color, Theme Shop preview, and 4×4 live-board multipliers

Context: Physical review first found the 3× glyph treatment too prominent in compact preview surfaces, then found the same treatment too prominent on the 4×4/16-cell live board. The one-cell and 2×2 treatments remain appropriate.

Decision: Divide the preview and 4×4 multipliers by 1.5, from 3× to 2×. Apply 2× to the Arcade Your Color swatch, every Theme Shop game screenshot, and the 4×4/16-cell live board. Keep the live SpriteKit contract at 1× for 1×1 and 2× for 2×2. Do not change geometry, glyph shapes, hit regions, difficulty, Zen's glyph-free gradient swatch, or any other grid presentation.

Consequences: Both preview surfaces and the densest live board become one-third smaller than P-029. Deterministic tests lock the 2× preview token, its resolved sizes, and the live 1×/2×/2× mapping. Per the owner's explicit instruction, this final 4×4 adjustment proceeds directly to merge and cable installation without another Simulator regression pass.

Revisit when: physical review shows the previews are still dominant or no longer legible, or a new preview surface needs an independently named scale.

## P-031 — Accept the paid-value, entitlement, refund, and account-deletion model

- Date: 2026-07-19
- Status: Accepted; resolves the product, price, provenance, refund-shortfall, Family Sharing, and account-deletion questions left open by P-008/P-010

Context: PimPoPom is preparing native StoreKit purchases while retaining one cross-platform profile, wallet, cosmetics catalog, and authoritative PHP ledger. Treating every coin as earned, or ad-free as one irreversible profile Boolean, cannot survive refunds, Family Sharing, moderation, or account deletion safely. The backend implementation is owned by the parent SpeedyTapper repository and remains a separate release gate.

Decision: Use four consumable coin products: `com.otcsoftware.pimpopom.coins.50.v1` at the US $2.99 price point, `com.otcsoftware.pimpopom.coins.100.v1` at $4.99, `com.otcsoftware.pimpopom.coins.500.v1` at $9.99, and `com.otcsoftware.pimpopom.coins.1000.v1` at $14.99. Each grants its named purchased-coin quantity plus an account-bound, non-expiring ad-free entitlement source while that verified transaction remains valid. Use `com.otcsoftware.pimpopom.removeads.lifetime` as a $1.99 non-consumable that grants ad-free without coins. Only the standalone non-consumable is Apple-restorable and Family-Shareable; family beneficiaries receive no coins. StoreKit supplies localized names and prices.

Keep one displayed spendable total while the server records earned and purchased provenance separately. Spend earned coins first, then purchased lots FIFO, and record the exact allocation for every cosmetic debit. A refund reverses the exact Apple transaction, removes its unspent purchased coins, revokes only cosmetics actually funded by that transaction, restores unrelated earned allocations, and exposes any remaining shortfall as `refundDebt`; future credits clear that debt before increasing spendable balance. `REFUND_REVERSED` restores the credit and refund-revoked cosmetics idempotently. Revoke ad-free only after the last valid entitlement source disappears. Administrative moderation never erases purchased balances, IAP history, or paid entitlement sources.

Coin purchases require an authenticated PimPoPom profile and the server-issued `appAccountToken`. Under the initial backend contract, standalone and Family-Shared Remove Ads reconciliation also requires a signed-in profile; do not promise anonymous recovery. Account deletion requires recent Google authentication plus the exact phrase `DELETE MY ACCOUNT`, erases the playable/public account, and retains only detached, pseudonymized paid settlement evidence required for Apple refunds and reversals. It removes active paid benefits from that deleted PimPoPom profile; it does not silently transfer them to a newly created profile.

Consequences: The native app must submit only the locally verified transaction JWS plus the current server binding, require server acknowledgement before finishing a transaction, and recover unfinished transactions from launch. Remove Ads exposes Restore Purchases; consumables recover only through unfinished transactions and the server ledger. Session state, not a local Boolean or the ad SDK, owns `adFree`, wallet composition, and `refundDebt`. Real purchase validation requires configured App Store products, Sandbox/TestFlight, Notifications V2, a deployed backend, and an explicit Sandbox/Production environment rollout. The dedicated IAP private key remains server-only and is never bundled or committed.

Revisit when: Apple changes Family Sharing/refund behavior, a separate native staging backend is available, launch territories expand beyond the United States and Canada, or support policy deliberately permits recovery onto a replacement PimPoPom profile after deletion.

## P-032 — Begin named StoreKit TestFlight validation

- Date: 2026-07-19
- Status: Accepted; advances P-027 only for the existing direct-email cohort after P-031 and the paid-value backend became available

Context: The owner accepted the five-product paid-value model, configured the products for the United States and Canada, confirmed the server-owned App Apple ID and IAP key deployment, and authorized a clean StoreKit-enabled TestFlight candidate. The named cohort still uses the live shared Hostinger profile, wallet, and ranking service; no separate native staging backend exists.

Decision: Advance PimPoPom to staging version `1.01` build `3`, keep the App Store app price Free, and distribute the same non-internal-only build only through the existing direct-email internal and external QA groups with public links disabled. The candidate may load and exercise the five real StoreKit products through TestFlight Sandbox, but it must require a server-bound profile, locally verified Apple transaction, and authoritative PHP acknowledgement before finishing or granting value. Coin-store review media may show the wallet because it materially explains paid-coin provenance; the dedicated Remove Ads surface must omit unrelated coin-balance presentation. Upload in-app review screenshots for all five products, but do not submit the production App Store version without a separate owner instruction.

TestFlight notes must disclose the live shared data service, five Sandbox products, optional non-blocking Game Center authentication, disabled live ads, server acknowledgement before value, Restore Purchases behavior, and in-app account deletion. Internal Sandbox purchase/restore and server-notification evidence remain gates before expanding beyond the named cohort or submitting a production release.

Consequences: App Store Connect pricing and product review metadata can be prepared, and build `3` can enter processing and Beta App Review without claiming production availability. A successful upload is not a successful purchase test; a successful Beta App Review is not an App Store release. The dedicated IAP key remains server-only and must never be used for Xcode signing, build upload, or inclusion in the app archive.

Revisit when: the named cohort expands, Apple review requests a different test account or disclosure, Sandbox reveals a transaction/notification mismatch, a separate staging backend is introduced, or the owner authorizes a production App Store submission.

## P-033 — Integrate test-safe AdMob, UMP, and ten-completion interstitial cadence

- Date: 2026-07-19
- Status: Accepted for implementation and Simulator automation; live activation and physical/TestFlight acceptance remain blocked

Context: PimPoPom already reserved exactly 50 points below the Speed Bar but still rendered internal-alpha copy, had no menu/results ad host, consent service, Privacy choices route, interstitial policy, or authoritative ad-free observer. The owner supplied the AdMob application and unit identifiers and accepted a combined Arcade/Zen interstitial after every ten terminal sessions, while requiring separate developer/demo, named QA, owner real-unit test, and public-live safety modes. Google Mobile Ads 13 replaces the standard adaptive recommendation with a large anchored-adaptive API whose documented height is 50–150 points; it cannot honor the already accepted strict 50-point gameplay budget without clipping.

Decision: Pin Google Mobile Ads 13.6.0 and UMP 3.1.0 behind app-owned main-actor `ConsentServing`/`AdsServing` protocols and one `AdsController`. Restore the PimPoPom session first and treat backend `sessionState.adFree` as tri-state authority: unknown makes no UMP/GMA request, true tears inventory down and clears the operational cadence, and only resolved false may request updated UMP information. Configure General maximum content, unspecified age treatment until the audience decision is accepted, disabled publisher personalization/first-party ID, no ATT/IDFA path, and no tracking purpose string before GMA initialization. Show **Privacy choices** only when UMP requires it.

Retain the exact 50-point active-game host and keep it empty/noninteractive during Arcade/Zen. Add stable menu and results hosts. Use Google's official fixed 320×50 banner centered within safe width because clipping or constraining a 50–150-point large adaptive creative is invalid; adopting large adaptive later requires a deliberate layout/reservation change. Let the SDK own refresh. Debug and release-optimized Staging use official demo units. A separate Owner Ads QA configuration accepts production units only from ignored configuration and fails without GMA's hashed test-device identifier. Checked-in Release remains disabled; a controlled live archive requires production units, no test identifiers, verified `app-ads.txt`, AdMob readiness, physical evidence, and separate owner authorization.

Give each started run a fresh app-local UUID. Count only Arcade Game Over and deliberate Zen Results in one persistent, deduplicated counter. At ten, retain `due` until a later results opportunity actually begins an interstitial. Attempt only after ranked submission reaches success/failure; never block proof submission, navigation, audio cleanup, or active play. No-fill/unloaded/offline/expired/presentation failure preserves due state. Reset only from `adWillPresentFullScreenContent`, then discard/reload after dismissal. Launch, foreground, consent/purchase dismissal, login, abandonment, and duplicate result rendering never present or count.

Consequences: Google SDK types stay out of gameplay/product rules, deterministic tests use zero-network fakes, build scripts reject test/live cross-contamination, the current 50-point board geometry remains stable, and purchased ad-free changes take effect from authoritative session state rather than coin balance. The app manifest records its UserDefaults/system-uptime required reasons and the current 50-entry SKAdNetwork list. The pinned GMA manifest still declares a linked Device ID marked for tracking plus advertising/product/location data despite the contextual runtime configuration, so App Store privacy answers must follow the aggregate archive report. UMP dashboard messages, owner test hash, `app-ads.txt`, archive privacy review, all-five-phone consent/geometry/interstitial tests, and live activation remain external gates; this decision authorizes no production deployment or App Store submission.

Revisit when: Google provides an adaptive format contract that fits 50 points, PimPoPom accepts a taller non-active host, age/teen treatment is finalized, the ad provider/privacy declarations change, physical accidental-tap review fails, or the owner authorizes a controlled live Release.

## P-034 — Fit full banners responsively and remove disabled ad surfaces

- Date: 2026-07-19
- Status: Accepted; supersedes P-007, P-008, P-017, and P-033 only for responsive Main Menu placement and disabled/ad-free host lifecycle

Context: A centered 320×50 banner plus the full lower Remove Ads button and copyright could not fit the accepted fixed Main Menu on standard-height iPhone 6/7/8/SE screens. Conversely, moving the compact control to the header on every phone needlessly weakened the reviewed taller-screen hierarchy. Disabled and already ad-free sessions also had no reason to retain visible placeholders, notes, or inaccessible empty banner containers.

Decision: Keep one centered fixed 320×50 menu banner in a root safe-area inset, with copyright directly above it and no scrolling. On portrait screens whose longest side is 667 points or shorter—the standard iPhone 6/7/8/SE family—replace the lower text button with one 44×44 crossed-AD header control immediately left of Coins. On taller menus, retain the full 112×44 Remove Ads text control at the bottom above the banner. Do not show either control until a backend session is resolved, and remove it when authoritative `sessionState.adFree` is true; neither coin balance nor local purchase state may infer this entitlement.

When ads are disabled or authoritative ad-free before a run starts, construct no menu, gameplay, or results banner container, placeholder, spacer, or ad note. An ad-supported Arcade/Zen run snapshots its empty, noninteractive 50-point gameplay reservation so asynchronous fill, no-fill, consent, or network state cannot move the board. If the backend becomes ad-free during that run, tear down the real ad view and accessibility surface immediately but retain only an invisible run-lifetime spacer until the current run ends, restarts, or leaves gameplay. Detach the menu banner whenever a pushed destination is visible so one hosted banner view cannot leak into Settings, shops, Leaderboard, or gameplay.

Consequences: The smallest accepted menu fits a standard-sized banner without scrolling, taller menus preserve the reviewed full purchase entry point, and an authoritative ad-free player sees neither purchase control nor ad footprint. Run geometry remains deterministic without representing an invisible spacer as an ad. UI automation covers both placement branches, exact centered 320×50 bounds, compact/tall copyright clearance, startup disabled/ad-free absence, and pushed-screen lifecycle; direct mid-run entitlement-transition automation remains required before live acceptance.

Revisit when: The supported-device floor changes, localized copy no longer fits the 112-point control, PimPoPom accepts an adaptive/taller banner, or physical accessibility and accidental-tap review requires a different separation rule.

## P-035 — Make the companion's front-facing pose reachable

- Date: 2026-07-19
- Status: Accepted; supersedes P-021 only for the front-facing tolerance and gameplay interaction surface

Context: The shared companion resolver recognized front only within one physical point of the exact horizontal axis. Store previews could begin centered, but ordinary menu and gameplay taps almost always resolved to a directional pose and could not reliably return the pet to front. Gameplay also reconstructed board coordinates through an inset that did not exist in the rendered SpriteView, and its visible pet/footer region did not forward taps.

Decision: Reserve a front-facing corridor extending 5% of active interaction width to each side of the rendered pet center, clamped to a 4-point minimum and 20-point maximum. Keep the existing half-turn boundary at 15%; the corridor remainder through that boundary is half-left/right and farther taps are full-left/right. Vertical distance remains irrelevant, so a tap directly on, above, or below the pet returns it to front. Resolve gameplay board coordinates across the complete rendered board width, and let a simultaneous gameplay-screen tap update pet facing without converting non-board UI taps into engine input. Preserve incremental adjacent-frame animation from the current pose and the menu's separate five-second sleep lifecycle.

Consequences: Front is intentionally hittable on the 80-point shop preview and full-screen menu/gameplay surfaces while the half/full directional zones remain distinct. Direct pet and Speed Bar-aligned taps can restore front in gameplay, header/footer taps may orient the companion without affecting score, and board scoring/proof semantics remain unchanged. Unit tests lock the tolerance clamps and board mapping; UI tests lock side-to-front transitions on the menu and gameplay screen.

Revisit when: physical review finds the 5% corridor too narrow or broad, a future pet has materially different visible width, or VoiceOver needs an explicit pose-control action.

## P-036 — Isolate owner production-ad QA from TestFlight demo inventory

- Date: 2026-07-19
- Status: Accepted; advances P-032/P-033 to TestFlight build 4 without authorizing live public ads

Context: Google Mobile Ads test-device identifiers mark production-unit requests as test traffic but do not choose different unit IDs per phone. One TestFlight binary therefore cannot use production units only for the owner's device and official demo units for every other tester. Build 3 is already awaiting its first external Beta App Review, and its app-wide review metadata accurately describes that older disabled-ad candidate.

Decision: Advance the named Staging candidate to version `1.01` build `4`. Keep Staging locked to Google's official fixed demo banner and interstitial units for every internal and external TestFlight tester. Separately cable-install **Owner Ads QA** only on the owner's iPhone SE, with PimPoPom production unit IDs and that physical phone's GMA-generated hashed test-device identifier supplied by ignored `0600` configuration. Never substitute the CoreDevice identifier, tester email, or a UMP debug hash, and never click a creative; every owner-real-unit creative must visibly say **Test mode** before it counts as evidence.

Set build 4's per-build **What to Test** after processing and add it to Internal QA. Do not overwrite the app-wide Beta Description or Review Notes while build 3 remains in review because doing so would make build 3's active review record inaccurate. After build 3 leaves review, update those global fields to describe the demo-labelled AdMob candidate, assign build 4 to External QA, enable automatic tester notification, and submit build 4 only if App Store Connect reports it ready for a new review. Do not withdraw build 3 implicitly.

Consequences: Other testers cannot receive live production inventory, the owner's production-unit verification remains physically isolated, and the external review remains truthful at every stage. Upload and internal testing can proceed while build 3 is pending, but external build-4 access and its two global metadata updates may wait on Apple's one-build-per-version review constraint. Public Release still requires production units without a test identifier, `app-ads.txt`, privacy/UMP review, physical evidence, and separate authorization.

Revisit when: build 3 leaves review, Google changes its per-request/test-device model, a dedicated internal-only bundle is accepted, or public live-ad release gates are complete.

## P-037 — Route TestFlight build 5 by the owner's app-visible device identifier

- Date: 2026-07-20
- Status: Accepted for named TestFlight build 5 only; supersedes P-036 for this archive without authorizing public live ads

Context: The owner requested one TestFlight binary that uses PimPoPom production ad units on the connected owner phone and Google's official demo units on every other tester device. GMA's test-device hash marks requests as test traffic but cannot choose ad-unit IDs. iOS does expose `identifierForVendor` (IDFV) to the app without using the hardware UDID or ATT.

Decision: Advance version `1.01` to build `5`. In the explicitly authorized Staging archive, hash the current IDFV locally with SHA-256 and compare it with one ignored private fingerprint. A match selects the supplied production banner/interstitial IDs and registers the phone's separate 32-character GMA test-device hash; a missing or nonmatching IDFV selects Google's demo banner/interstitial IDs and supplies no test-device identifier. Store neither the raw IDFV nor any owner email/account marker, transmit no IDFV through PimPoPom, and keep all selector inputs in ignored `0600` configuration. Restrict this mode to Staging and validate the demo fallback, production-format owner units, one GMA hash, and one SHA-256 fingerprint at build time. If the owner's IDFV changes, fail safely to demo inventory.

Also include the Pixel-theme HUD correction in build 5: use square segmented Speed Bar chrome, a square multiplier badge, and code-native pixel hearts while retaining the existing Jersey 10 labels and semantic red life color. Use the existing TestFlight beta description, testing instructions, and review notes, adding the release-note line **Minor fixes for Pixel Theme**.

Consequences: The same TestFlight binary can exercise the production units safely on the registered owner phone while external testers remain on Google demo inventory. The archive necessarily contains public production unit IDs, the one-way owner fingerprint, and the GMA test hash, but contains no raw Apple UUID or secret key. Every owner creative must visibly say **Test mode** and must never be clicked. This exception remains named-cohort QA only; public Release still requires live-mode review, no test hash, `app-ads.txt`, privacy/UMP completion, physical evidence, and separate authorization.

Revisit when: the IDFV changes, build 5 leaves TestFlight, Apple or Google changes identifier/test-device behavior, the named cohort expands, or public live-ad release gates are complete.

## P-038 — Correct TestFlight owner routing and use a three-final interstitial cadence

- Date: 2026-07-20
- Status: Accepted for named TestFlight build 6; supersedes P-037 for owner routing and P-033 only for cadence

Context: Build 5 compared the IDFV fingerprint captured from a development-signed cable install. The installed TestFlight build safely fell back to Google demo inventory because Apple derives the App Store/TestFlight vendor identity differently and returned a distinct IDFV. Apple also documents that IDFV may reset after every app from a vendor is removed. The owner additionally requested interstitial eligibility after every three completed run finals instead of ten, plus clearer main-menu outlines for Leaderboard, Profile, and Settings.

Decision: Advance version `1.01` to build `6`. Keep the existing owner-split Staging mode, production owner units, registered GMA test-device hash, and demo fallback, but accept up to four unique ignored SHA-256 IDFV fingerprints. Configure this archive with only the owner's observed cable-install and TestFlight-install fingerprints. Store and compare no raw UUID, transmit no IDFV, and continue to treat a missing/nonmatching value as a non-owner demo route. This remains a brittle named-build QA exception rather than a general identity mechanism; a reset IDFV requires another explicit fingerprint update.

Change the persistent, deduplicated combined Arcade/Zen threshold from ten completed finals to three. Start a fresh `v2` counter generation so a partial ten-run count is not reinterpreted. Preserve all other safeguards: ad-free players do not count or present; duplicate result rendering counts once; no-fill, unloaded, offline, and failed presentation remain due; and the count resets only when SDK presentation actually begins.

Give the menu Leaderboard and Profile controls border-only blue and green accents using contrast-aware theme tokens. Give Settings an 85%-white border, with a faint dark under-stroke on Light so the requested white edge remains readable. Do not recolor the controls' icons, labels, or backgrounds.

Consequences: The TestFlight copy on the currently observed owner installation selects the two PimPoPom production units while its registered GMA hash keeps requests in visible test mode; every other tester remains on Google's demo units. Build 5 cannot be repaired in place. Build 6's interstitial appears more frequently and therefore needs explicit accidental-tap and results-transition review before broader distribution. IDFV matching is not stable enrollment, App Attest, DeviceCheck, or an App Store release identity system.

Revisit when: the owner reinstalls all OTC Software apps and the IDFV changes, the beta cohort expands, explicit first-party owner enrollment is implemented, three-final frequency harms gameplay or accidental-tap safety, or public live ads are authorized.

## P-039 — Fill the fixed gameplay banner and compact successful score status

- Date: 2026-07-20
- Status: Accepted for TestFlight build 6; supersedes P-033/P-034 only for the active-game banner and result-save presentation

Context: The gameplay layout already reserved a stable 50-point safe-area footer below the Speed Bar, but `AdBannerSlot` explicitly prohibited attaching the banner during Arcade/Zen. This made the build appear to lose ads as soon as play began. On signed-in Arcade Results, successful leaderboard persistence also occupied a separate 52-point styled card and could make the small-screen result surface require scrolling once its banner was present.

Decision: Permit the same fixed 320×50 banner to rehost in the existing gameplay footer for ad-supported Arcade and Zen runs. Keep it outside the board and gameplay gesture surface, below the Speed Bar, without resizing the board when loading, filling, or failing. Preserve the existing fail-closed behavior: disabled, unresolved, or authoritative ad-free sessions construct no ad surface; a mid-run ad-free transition tears down the creative immediately and retains only invisible run-lifetime geometry. On Results, render saving and successful leaderboard persistence as one small inline status row without a card or minimum height. Retain a styled status card only when an upload failed and the player needs the Retry score upload action.

Consequences: Eligible ads are visible on menu, gameplay, and results instead of disappearing during play, and successful signed-in Results recover vertical space on standard-height phones. One GMA banner view remains app-owned and is safely reparented between the three surfaces. Simulator fakes must prove exact 320×50 gameplay placement and ad-free absence; a physical TestFlight pass must still confirm separation, no accidental gameplay/ad tap crossover, real creative behavior, and fixed Results layout before production release.

Revisit when: physical review finds the gameplay banner distracting or prone to accidental taps, localization makes the compact save status wrap, a larger adaptive format is accepted, or the gameplay footer geometry changes.

## P-040 — Route unaffordable cosmetic taps directly to Buy Coins

- Date: 2026-07-20
- Status: Accepted for TestFlight build 6

Context: Theme Shop and Pet Shop already exposed a Buy Coins button, but tapping an unowned item above the authenticated wallet balance only displayed “You need … more coins.” Pet Shop also retained a general “Choose one pet…” instruction and a newly-purchased “is yours and selected” message even though the tile state already communicated those outcomes. These rows consumed scarce vertical space without advancing the intended action.

Decision: When an authenticated player taps an unowned theme or pet whose authoritative balance is below its catalog price, open the shared Buy Coins StoreKit sheet immediately and do not call the cosmetic debit endpoint. Keep signed-out purchase taps on the existing sign-in gate. Remove the authenticated Pet Shop instruction, both theme/pet shortfall messages, and the redundant newly-purchased-pet success message. Preserve actionable service errors, pending progress, selection/show/hide feedback, server prices, and server-authoritative balance/ownership checks.

Consequences: Insufficient-funds taps take the shortest valid route to localized StoreKit products, while shops use less vertical space and no longer echo state already visible on the tile. No client-side coin grant, price trust, or cosmetic ownership inference is introduced; the StoreKit and backend transaction boundaries remain unchanged.

Revisit when: the StoreKit sheet gains a product recommendation based on shortfall, signed-out purchasing becomes supported, or physical review finds direct modal presentation too abrupt.

## P-041 — Require explicit Game Center participation and support Turn Off

- Date: 2026-07-20
- Status: Accepted; supersedes P-027 only for launch-time Game Center authentication and Profile controls

Context: Installing `GKLocalPlayer.local.authenticateHandler` during every cold launch can authenticate an already signed-in Apple player immediately and can show Apple's Game Center banner before the player has chosen to use that optional surface. The owner requested a clickable Profile control and a way to disconnect or prevent leaderboard publication. GameKit exposes authentication and the Apple-supplied sign-in controller, but it does not expose an app-level sign-out method. PimPoPom also has no current Game Center score-submission or Hostinger mirror path, so no result is presently published to Apple's leaderboard.

Decision: Default PimPoPom Game Center participation to **Off**. Do not install Apple's authentication handler on a fresh or upgraded installation until the player taps **Connect** in Profile. Persist the preference only after Game Center successfully authenticates; cancellation or failure must not create a future-launch opt-in. A successful opt-in may resume non-blocking authentication on later launches. While connected, expose **Turn Off**: invalidate outstanding callbacks, remove the authentication handler, clear the local opt-in, and return Profile to the Off state. Explain that this controls PimPoPom only and that the Apple account is managed in iOS Settings. Keep deterministic UI tests from presenting Apple's controller.

Do not describe Turn Off as Apple account sign-out, do not claim it deletes an Apple leaderboard entry, and do not add a client submission call. Before the future P-011 server-fed mirror is enabled, add authenticated server-side publication consent and unlink semantics so a device-local flag is not the only enforcement boundary. The current App Store Connect leaderboard description should be the concise production-facing sentence **Global Arcade high scores.**; Apple's own Prerelease panel remains until the component is submitted and live.

Consequences: A new player receives no cold-launch Game Center prompt or banner from PimPoPom. Players deliberately opt in from Profile and can later stop PimPoPom's Game Center use without affecting local play, Google/PimPoPom identity, the Hostinger global leaderboard, economy, purchases, or the Apple account itself. Existing builds that had authenticated Game Center do not silently migrate that state into participation because the new preference starts false. Physical validation must cover fresh install, upgrade, successful connection, cancellation, Turn Off, Apple account change, parental restrictions, and relaunch.

Revisit when: the Hostinger binding/outbox is implemented, Apple adds an app-level sign-out or score-deletion API, Game Center becomes authoritative, or product policy removes the optional Apple leaderboard.

## P-042 — Mirror authoritative PimPoPom achievements through the Game Center server path

- Date: 2026-07-20
- Status: Accepted design; blocked on the same verified player binding and publication-consent backend required by P-011/P-041

Context: PimPoPom already has five server-authoritative, nonrepeatable achievements with durable stable IDs and historical reconciliation. The owner requested that they also appear in Game Center. Direct `GKAchievement.report` calls would let a modified client publish fabricated completion and could silently combine different PimPoPom profiles under one Apple player. Apple's server achievement submission API can instead project server truth, but it accepts an Apple scoped player identifier and therefore inherits the unresolved trusted-identity association described by P-011.

Decision: Extend the future Game Center binding/outbox to achievements. Reserve the exact permanent vendor IDs and point values listed in `docs/API_CONTRACT.md`, totaling 100 Game Center points. All five are visible and nonrepeatable. Because the current API exposes no numeric progress, map `locked` to no submission and both `claimable` and `claimed` to 100%; an achievement is completed when its server goal unlocks, not when the separate coin reward is claimed. Use an explicit five-entry allowlist, reconcile historical eligibility before first backfill, and enqueue future unlocks transactionally. Submit only monotonic 100% state, with TestFlight prerelease and production routing kept distinct.

Require explicit Game Center Connect plus an authenticated PimPoPom profile, a verified one-to-one Apple/PimPoPom binding, and server-held publication consent. Turn Off revokes consent and cancels unsent outbox work but does not erase already-published Apple achievements. Account deletion removes binding, consent, and pending work without resetting the independent Apple account. Apple-account or PimPoPom-account changes require explicit confirmation and may not auto-rebind by display name or email. Game Center completion never grants PimPoPom coins, ownership, rank, or profile authority.

Consequences: Game Center can show familiar achievements without becoming an economy authority or trusting the iOS binary. Already-earned goals can backfill after consent, and later unlocks remain idempotent. This does require five configured App Store Connect achievement records and images, backend identity binding/outbox work, correction policy, and physical TestFlight validation before any component is attached to a submitted app version.

Revisit when: Apple documents a stronger client/server scoped-identifier association, PimPoPom adds numeric achievement progress, a goal meaning changes, or the Game Center surface is removed.
