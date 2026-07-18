# Design QA history

This file is historical evidence, not proof of the current TestFlight or App Store release. Every entry must identify the exact PimPoPom commit, version/build, device or Simulator, OS, configuration, and capture paths.

## Current evidence

The playable Xcode alpha has current API-gate, final-name, and Disco-corner evidence on the named iPhone SE 2022 Simulator at exact implementation commit `bab0709`. That same commit was development-signed with the selected `com.otcsoftware.pimpopom` identity, installed, and launched as **PimPoPom** on the owner's physical iPhone SE with iOS 26.3; this was not a structured device review. Prior Leaderboard/gameplay evidence remains at `c0bcc69`, Glow/Light/Pixel app-icon and Home Screen quick-action evidence at `30503e3`, and earlier checkpoints below. Earlier physical commit `d3ffd87` used retired bundle ID `com.otcsoft.pimpopom.alpha`. The 13 mini/13 Pro profiles were not rerun. No physical 13 mini/13 Pro, TestFlight, or App Store QA has been performed; no Simulator result validates 60/120 Hz touch timing.

## 20260718 API gate, final name, and Disco corner pass — 2026-07-18

- **Candidate/version/build:** PimPoPom 0.1.0 (1), internal alpha.
- **Implementation commit:** `bab07090ccea2a42f34d2ebfc4a176d9bf3b3ef1` (`fix: align native client with 20260718 backend`).
- **Backend reference:** parent SpeedyTapper `main` commit `371d59815fa7c9e562e69d05962ac6063de0b40f`, retained deployment tag `hostinger-20260718-1`, and live Hostinger build `20260718-1`.
- **Simulator and configuration:** named iPhone SE (3rd generation, 2022) Simulator on iOS 26.5 (23F77), Debug, deterministic offline fixtures for authenticated UI paths; production mutations and real audio output disabled for automation.
- **Automated checks:** `Scripts/check.sh` passed strict Swift formatting, 86 committed asset/provenance hashes, 29 pure Swift package tests, generic Simulator build and compiled metadata assertions, 69 native unit tests, all 22 SE XCUITest paths, and `git diff --check`. Xcode reported 91 passed native/UI tests with zero failures, skips, or expected failures; 120 checks ran including the core package.
- **Contract findings:** ranked start sends exact build ID `20260718-1`; finish echoes the issued ticket metadata. Raw session and finish fixtures containing additive `achievementSnapshot` objects decode successfully without changing the current models. Existing `/api/leaderboard` remains in use because it retains rank/context fields; no authenticated production write was sent.
- **Visual capture:** the local Xcode-result attachment **SE Disco gameplay polish** was inspected at the exact implementation commit and was not copied into repository evidence.
- **Visual findings:** the active cyan tile remained highly saturated with internal backlight and scratch wear. Its exterior light was confined to a narrow rounded contour; the prior straight square color frame was absent, and the four true corner wedges remained opaque black over the concrete/reflection field. The same base → clipped glow → cell contract is shared by live SpriteKit cells and SwiftUI previews.
- **Physical install evidence:** the exact commit built for the owner's connected iPhone SE (3rd generation), iOS 26.3 (23D127), with automatic Apple development signing under team `APX2925X66`. The bundle passed strict signature verification. CoreDevice installed and launched identifier `com.otcsoftware.pimpopom`, then reported installed name **PimPoPom**, version 0.1.0 (1).
- **Remaining checks:** owner visual confirmation of 1×1/2×2 Disco cells on the physical phone; a real authenticated ranked finish against build gate `20260718-1`; physical touch/audio review; 60/120 Hz timing; current-batch 13 mini/13 Pro layout; Google OAuth under the exact explicit App ID; accessibility; Game Center; StoreKit; ads; TestFlight; and App Store review.
- **Evidence statement:** exact-commit SE Simulator regression/visual evidence plus physical signing/install/launch evidence; not an authenticated-write, structured physical-device, multi-device, accessibility-matrix, TestFlight, or production-release validation.

## Physical iPhone SE selected-bundle install-and-launch checkpoint — 2026-07-18

- **Candidate/version/build:** PimPoPom 0.1.0 (1), internal alpha.
- **Source commit:** `64f07f00e504f30388a7b78b429cd2b781708b52` (`docs: record leaderboard polish validation`), containing implementation commit `c0bcc69ae907cced24decc1cca140ab96888b640`.
- **Device and OS:** owner's wired iPhone SE (3rd generation), iOS 26.3 (23D127); paired and Developer Mode enabled.
- **Configuration:** Debug; automatic Apple development signing with team `APX2925X66`; bundle `com.otcsoftware.pimpopom`.
- **Evidence:** the physical-device build succeeded, the signed bundle passed strict code-signature verification, CoreDevice reported successful installation of exact bundle `com.otcsoftware.pimpopom`, and CoreDevice then reported successful application launch.
- **Scope:** confirms compilation, signing, packaging, installation, and process launch for the selected persistent bundle identity and current gameplay implementation.
- **Not covered:** structured physical visual/gameplay/touch/listening review; Google sign-in for the new bundle; authenticated backend writes; 60/120 Hz timing; accessibility; audio routes; Game Center; StoreKit; ads; TestFlight; or App Store review.
- **Evidence statement:** exact-source physical install-and-launch checkpoint only; not a structured physical-device or production validation.

## Leaderboard, ranked-contract, and gameplay-polish Simulator pass — 2026-07-18

- **Candidate/version/build:** PimPoPom 0.1.0 (1), internal alpha.
- **Implementation commit:** `c0bcc69ae907cced24decc1cca140ab96888b640` (`fix: restore ranked scores and gameplay polish`).
- **Device and OS:** named iPhone SE (3rd generation, 2022) Simulator on iOS 26.5 (23F77).
- **Configuration:** Debug; deterministic offline fixtures for authenticated UI paths; production mutations and real audio output disabled for automation. The generic and SE builds assert bundle ID `com.otcsoftware.pimpopom`.
- **Reviewed states:** compact Leaderboard rows with fixed trailing scores and no Legacy chip; vivid Disco gameplay target with black exposed corners, scratch wear, and concrete/reflected-light backing; hidden Achievements wallet balance; launch-local rules-to-slogans lifecycle; centered Missed/Too slow copy; three-point Your Color outline; and accepted/withheld ranked-finish confirmation logic.
- **Capture:** final local Xcode-result attachments named **SE leaderboard parity** and **SE Disco gameplay polish** were inspected. They were not copied into repository evidence, so no durable screenshot is claimed for these changed pixels.
- **Automated checks:** `Scripts/check.sh` passed strict Swift formatting, 86 committed asset/provenance hashes, 29 pure Swift package tests, the generic Simulator build and compiled metadata assertions, 68 native unit tests, all 22 SE XCUITest paths, and `git diff --check`. The Xcode result contains 90 passed tests with zero failures, skips, or expected failures; 119 tests ran including the core package.
- **Contract evidence:** the native build now matches live Hostinger gate `20260716-1`; genuine engine proof tuples reach the finish request; a verified response must echo the exact run UUID, while review/quarantine are persisted but withheld. Public health/HTML/Leaderboard reads succeeded and the current Leaderboard fixture rendered scores. No authenticated production write was sent.
- **Visual findings:** three-digit and five-digit scores remained visible at the right edge of SE Leaderboard rows and the obsolete Legacy chip was absent. The Disco target was strongly saturated with visible texture, opaque black rounded-corner surrounds, and cyan/violet/red illumination across the black field/header backing.
- **Remaining checks:** create the Google iOS OAuth client for exact bundle `com.otcsoftware.pimpopom`; sign/install that new app identity; perform a real authenticated ranked finish and verify the resulting shared PHP row; repeat compact layout on 13 mini and 120 Hz timing on 13 Pro; review physical touch/audio, accessibility settings, Game Center, StoreKit, and ads.
- **Evidence statement:** exact-commit SE Simulator build/regression plus implementation-time attachment inspection; not authenticated-write, physical-device, multi-device, accessibility-matrix, listening, TestFlight, or App Store validation.

## Selectable app icons and Home Screen quick action — 2026-07-18

- **Candidate/version/build:** PimPoPom 0.1.0 (1), internal selectable-icon candidate.
- **Implementation commit:** `30503e3ecffc48b5322c46df3a4ae88216aff718` (`feat: add selectable app icons and shortcut`).
- **Device and OS:** named iPhone SE (3rd generation, 2022) Simulator on iOS 26.5 (23F77).
- **Configuration:** Debug; ImageGen Glow is the primary asset-catalog icon, while Light glass and Pixel are registered alternates. The retired black-outline candidate is retained only under branding sources and is not present in the compiled icon catalog.
- **Reviewed states:** all three 1024×1024 runtime icons and 180×180 Settings previews; the three-choice Settings card with Glow selected; a cold `pimpopom://settings/icon` activation; the actual SpringBoard long-press menu; and its direct return to the dismissible icon selector.
- **Captures:** [`SE Home Screen Change Icon quick action`](evidence/2026-07-18/se-home-screen-change-icon-quick-action.png) SHA-256 `cb29c22edaa86c1d832e99ac591afc4c25de704b70d915497a88e73b57ab2938`; [`SE Change Icon deep-link Settings`](evidence/2026-07-18/se-change-icon-deeplink-settings.png) SHA-256 `64c8d9b4d9582c5cefc9ec9a5d658cdcd32e2e120214fc3ffb10865e4127d89e`.
- **Automated checks:** `Scripts/check.sh` passed strict Swift formatting, 86 committed asset/provenance hashes, icon catalog/opacity/geometry/master-parity checks, 29 pure Swift package tests, the generic Simulator build, compiled primary/alternate icon and shortcut/deep-link metadata assertions, all 85 native app/UI tests, and `git diff --check`, with zero failures, skips, or expected failures.
- **Behavior evidence:** controller tests treat iOS as the icon-selection authority, map `nil` to Glow, map exact Light/Pixel catalog names, and reject unsupported devices without changing state. Shortcut/deep-link tests cover URL validation, shortcut payload handling, one consumable request, cold custom-URL activation, the system external-URL confirmation, and direct Settings presentation. A one-off SpringBoard XCUITest long-pressed the installed Simulator icon, found **Change Icon**, captured the menu, tapped the action, and verified that Settings opened without the external-URL confirmation; this slow path is retained as visual evidence rather than a permanent test because SpringBoard automation imposed two unrelated one-minute idle waits.
- **Visual findings:** Glow appeared as the default Home Screen icon and all three choices remained legible at Settings size with the exact `Pim`, `Po`, `Pom` spelling. Glow has no black letter outline, Light uses the requested pale glass treatment, and Pixel uses stepped lettering over a dark pixel field. No clipping or layout jump was observed on the SE selector.
- **Remaining checks:** physical-iPhone install and Home Screen/context-menu review; actual primary-to-Light-to-Pixel switching on hardware; Spotlight, Settings, notification, dark/tinted icon, localization, VoiceOver, Dynamic Type, and Reduce Motion review; final brand/trademark acceptance and App Store review.
- **Evidence statement:** exact-commit asset/build/metadata/regression evidence plus actual iOS Simulator Home Screen context-menu and deep-link evidence; not physical-device, TestFlight, App Store, localization, accessibility-matrix, or final-brand approval.

## Stacked-wordmark app-icon asset pass — 2026-07-18

- **Candidate/version/build:** PimPoPom 0.1.0 (1), internal app-icon candidate.
- **Implementation commit:** `c7b15d9eb005208d1e85ddfd82f2368350ebbeca` (`feat: add stacked PimPoPom app icon`).
- **Configuration:** opaque universal 1024×1024 sRGB asset-catalog icon; built with Xcode 26.5 for generic iOS Simulator and exercised by the complete named iPhone SE 2022 Simulator suite on iOS 26.5 (23F77).
- **References:** the live code-native wordmark colors and the retained first PimPoPom app-icon candidate. OpenAI's built-in image-generation tool created the text-free luminous backdrop; Swift/CoreGraphics/CoreText place the exact three-line wordmark deterministically.
- **Reviewed states:** full master/runtime export at 1024 pixels and downsampled 180-, 87-, and 60-pixel views. The spelling is exactly `Pim`, `Po`, `Pom`, with one progressive right indent per line; the previous three-disc foreground is absent.
- **Asset evidence:** the retained master and runtime export are byte-identical at SHA-256 `cf0c5ab761dcbd5a9760b1fe3c1924267139299233bf307bcbc63470196393c7`. Two consecutive renderer runs also matched byte-for-byte. The generated backdrop, prompt, renderer, earlier rollback master, and both icon generations pass the committed hash manifest.
- **Automated checks:** `Scripts/check.sh` passed strict Swift formatting, 72 committed asset/provenance hashes, app-icon opacity/geometry/master-parity validation, 29 pure Swift package checks, the generic Simulator build including asset-catalog compilation, and all 80 native app/UI tests with zero failures, skips, or expected failures. `git diff --check` passed.
- **Remaining checks:** install the candidate on a physical iPhone and review Apple's applied mask on the Home Screen, Spotlight, Settings, and notifications; review light/dark/tinted icon appearances if those variants are added; perform final identity, trademark, and App Store acceptance.
- **Evidence statement:** exact-commit source/export, small-size visual inspection, asset-catalog compilation, and regression evidence only; not a physical Home Screen, TestFlight, App Store, or final-brand approval.

## Achievements and canonical-cell refinement Simulator pass — 2026-07-18

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `fd11703731f0cec0a160323729439cd96a365f4a` (`Add native achievement rewards and polish game cells`).
- **Device and OS:** named iPhone SE (3rd generation, 2022) Simulator on iOS 26.5 (23F77).
- **Configuration:** Debug; deterministic `--uitesting --ui-test-achievements-profile` fixture for the claim path; production mutations and real audio output disabled for automation; ads, StoreKit, and Game Center remain non-connecting/non-granting placeholders.
- **References:** deployed PHP achievement contract and parent SpeedyTapper `main` commit `209ee6ca84b17bc81144d2dc60c613feeae05dc0`; the existing native Classic, Light, Disco, and Pixel visual system.
- **Screens/states:** Achievements progress/balance plus locked, claimable, and claimed cards in all four themes; menu reward-ready marker; Theme Shop solid crosses; live Disco active target and corners; live Pixel target grain.
- **Accessibility settings:** Simulator defaults only. Stable identifiers, card state/value, progress, coin balance, claim action, and updated menu summary were exercised by XCUITest. VoiceOver, Dynamic Type extremes, Increase Contrast, and Reduce Motion were not reviewed.
- **Capture:** no screenshot was retained. Inspection was live through Computer Use; earlier captures below are not evidence for these changed pixels.
- **Automated checks:** `Scripts/check.sh` passed strict Swift formatting, asset/provenance validation, 29 pure Swift package checks, the generic Simulator build, 61 native app unit tests, all 19 SE XCUITest paths, and `git diff --check`. The Xcode result contains 80 passed tests with zero failures, skips, or expected failures.
- **Manual Simulator inspection:** the Achievements layout remained readable and theme-consistent in Classic, Light, Disco, and Pixel. The offline claim fixture moved from 1/5 and 9 coins to 2/5 and 10 coins and updated the menu. Classic, Light, and Disco crosses had filled centers. Disco's active cyan target was strongly saturated and the exposed areas around each rounded tile were black. Pixel gameplay showed subtle but clearly brighter clipped square samples; the same renderer reached previews.
- **Contract evidence:** tests cover the exact public GET and authenticated CSRF claim routes/body, validated authoritative response/balance, session/player generation, 401/403 reconciliation, malformed response rejection, and exact five fallback IDs/rewards. A signed-out live GET was read safely. No authenticated Hostinger claim or other production write was sent.
- **Remaining checks:** real Google sign-in and authenticated claim; physical installation/visual/touch review; current-batch 13 mini/13 Pro reruns; 60/120 Hz timing; VoiceOver, Dynamic Type, contrast, and Reduce Motion; audio listening/routes; live ads; StoreKit; and actual Game Center integration.
- **Evidence statement:** exact-commit SE Simulator regression and implementation-time visual evidence only; not authenticated-write, physical-device, multi-device, accessibility-matrix, listening, or production-release validation.

## Canonical tile and pet-follow Simulator pass — 2026-07-17

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `a607adc9db0ee9da39b49e47b41b6ee08fd0099f` (`feat: unify tile art and pet tap tracking`).
- **Device and OS:** named iPhone SE (3rd generation, 2022) Simulator on iOS 26.5 (23F77).
- **Configuration:** Debug; deterministic `--uitesting` fixtures for automation; production network mutations and real audio output disabled for automated paths; ads, StoreKit, and Game Center remain non-connecting/non-granting placeholders.
- **Screens/states:** fixed menu utility row; Disco, Light, and Pixel live gameplay plus Your Color; Pancake menu and Leaderboard composition; and Pancake left/right menu following.
- **Accessibility settings:** Simulator defaults only. Stable identifiers/values and principal paths were exercised by unit/XCUITest. VoiceOver, Dynamic Type extremes, contrast, and Reduce Motion were not reviewed.
- **Capture:** no screenshot was retained. Inspection was live through Computer Use; earlier captures below are not evidence for these changed pixels.
- **Automated checks:** `Scripts/check.sh` passed strict Swift formatting, asset/provenance validation, 29 pure Swift package checks, the generic Simulator build, 50 native app unit tests, all 18 SE XCUITest paths, and `git diff --check`. The Xcode result contains 68 passed native tests and zero failures.
- **Manual Simulator inspection:** the menu coin value was opaque over its lower-right badge; active Disco cells were vivid, scratched, and strongly backlit over the retained darker uneven floor; Light cells showed a clipped crystal gradient/specular treatment; Pixel cells showed faint clipped grain and a full-size pixel glyph; both themes' Your Color swatches matched their live cells; Pancake sat fifteen points lower relative to its floor on menu/Leaderboard surfaces; and menu taps produced clean full-left and full-right poses without the artifacted left frame.
- **Behavior evidence:** deterministic tests cover equal canonical bounds for all six glyphs across smooth/pixel paths and 14/24/90-point boxes, material tokens and Pixel clipping/filtering/border composition, opaque outer badge overlays, shared horizontal tap zones, board-gap presentation routing without engine actions, Pancake surface offsets, and mirrored full-left policy. XCUITest covers menu/gameplay facing, sleep/wake, and Pancake menu/Leaderboard presence. A final independent read-only review found no concrete remaining defect.
- **Remaining checks:** physical installation and structured touch/visual review; current-batch 13 mini/13 Pro reruns; 60/120 Hz timing; VoiceOver, Dynamic Type, contrast, Reduce Motion, and performance profiling; authenticated production mutations; listening/audio-route checks; live ads; StoreKit; and actual Game Center integration.
- **Evidence statement:** exact-commit SE Simulator build/regression and implementation-time live visual evidence only; not physical-device, multi-device, authenticated-write, listening, or production-release validation.

## Theme, feedback, and current-pose companion Simulator pass — 2026-07-17

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `e2294def68434d0282d1b9b4e138a40e78e18587` (`feat: refine themes feedback and pet animation`).
- **Device and OS:** named iPhone SE (3rd generation, 2022) Simulator on iOS 26.5 (23F77).
- **Configuration:** Debug; deterministic `--uitesting` fixtures for automation; production network mutations and real audio output disabled for automated paths; ads, StoreKit, and Game Center remain non-connecting/non-granting placeholders.
- **References:** parent SpeedyTapper web `main` commit `209ee6ca84b17bc81144d2dc60c613feeae05dc0` and the owner-supplied menu-badge, Theme Shop, Disco-floor, and gameplay screenshots. The Disco photograph was used as visual direction only; the implementation reuses retained in-repository textures.
- **Screens/states:** fixed menu utility row and feature icons; all four candidate-theme previews under changing selections; Pixel gameplay Your Color presentation; centered pre-run Get ready; and a live Disco target over the concrete/scratched-floor treatment.
- **Accessibility settings:** Simulator defaults only. Stable labels/identifiers, selected-but-undimmed theme actions, announcement labels, current displayed pet-facing values, and principal UI paths were exercised by unit/XCUITest. VoiceOver, Dynamic Type extremes, contrast, and Reduce Motion were not reviewed.
- **Capture:** no new screenshot was retained for this checkpoint. Inspection was live through Computer Use; earlier exact-commit captures below are not evidence for these changed pixels.
- **Automated checks:** `Scripts/check.sh` passed strict Swift formatting, asset/provenance validation, 29 pure Swift package checks, the generic Simulator build, all 58 native unit/UI tests, and `git diff --check`. The Xcode result reports 58 passed tests and zero failures, skips, or expected failures.
- **Manual Simulator inspection:** the darker Pim gradient remained legible; coin and rank badges sat on the lower-right and upper-right button corners; all four candidate previews stayed bounded and distinct; the selected Light tile no longer dimmed; Pixel's left-anchored Your Color swatch matched its square board-cell treatment; Get ready appeared as a centered illuminated announcement; and a live Disco target used brighter color, scratch texture, and silver edging. The final inactive Disco token `#908f8c`, an exact 40% RGB reduction from `#f0efea`, was applied after live inspection and is covered by deterministic token assertions and the final passing build, not a post-change visual capture.
- **Behavior evidence:** structured tests cover candidate-theme preview isolation, the 25% Pixel scale, exact Disco tokens, shared preview/game-cell geometry, one-second pre-engine announcement timing, no Get ready replay after life loss, centered Too early/Too slow resolution, all current-pose directional pet transitions, sleep/wake frames, and `.lifeLoss` sound routing. A separate final read-only diff review found no blockers.
- **Audio evidence:** the retained loss cue hash/provenance validation and event/controller path passed. Simulator automation suppresses real audio, so this is not listening evidence for the `oops` cue.
- **Remaining checks:** physical installation and structured touch/listening review; a post-token visual check of the final inactive Disco tile; current-batch 13 mini/13 Pro layout reruns; 60/120 Hz touch timing; VoiceOver, Dynamic Type, contrast, and Reduce Motion; real Google sign-in/authenticated mutations; audio routes/interruptions/Silent switch; live ads; StoreKit; and actual Game Center integration.
- **Evidence statement:** exact-commit SE Simulator build/regression and limited implementation-time visual evidence only; not physical-device, audio-listening, authenticated-write, multi-device, or production-release validation.

## Leaderboard, theme, and companion polish Simulator pass — 2026-07-17

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `cccdae2ca5179213b34d6adf6f16466d7c18ba64` (`feat: polish leaderboard themes and pet controls`).
- **Device and OS:** named iPhone SE (3rd generation, 2022) Simulator on iOS 26.5 (23F77).
- **Configuration:** Debug; deterministic `--uitesting` fixtures for automation; production network mutations and real audio output disabled for automated paths; ads, StoreKit, and Game Center remain non-connecting/non-granting placeholders.
- **References:** parent SpeedyTapper web `main` commit `209ee6ca84b17bc81144d2dc60c613feeae05dc0` and the owner-supplied utility badge, Disco preview, and gameplay glyph screenshots.
- **Screens/states:** fixed menu utility row and feature buttons; whole-tile Theme Shop; live public Leaderboard; signed-out Profile/Game Center placeholder; Pet Shop Foka/Kesha placement; gameplay Your Color presentation; and Game Over without the obsolete local/service/version panel.
- **Accessibility settings:** Simulator defaults only. Stable labels/identifiers, menu rank value, whole-tile theme actions, placeholder alert, fixed geometry, and principal flows were exercised by unit/XCUITest; one-element Leaderboard rows and non-blocking hidden feedback were confirmed in final code review. VoiceOver, Dynamic Type extremes, contrast, and Reduce Motion were not reviewed.
- **Capture:** no new screenshot was retained for this checkpoint. Earlier exact-commit visual captures remain linked below and are not evidence for the changed screens here.
- **Automated checks:** `Scripts/check.sh` passed 29 pure Swift checks, 40 native app tests, a generic Simulator build, all 17 SE XCUITest paths, 65 committed asset hashes plus format/geometry/provenance validation, strict Swift formatting, and `git diff --check`. The final Xcode result contains 57 passed tests and zero failures/skips.
- **Manual Simulator inspection:** exact web coin art and black-bordered coin/rank badges rendered on the fixed menu; the trophy showed fixture rank `#6`; Pet Shop/Theme icons were larger and leading; and the enlarged slogan used the revised 10% shift. Theme Shop had no nested Select buttons, whole tiles changed selection, and Disco retained a black preview under Light. The live public Leaderboard rendered 30 Arcade rows without a service footer, with pets below ranks and wider details. Signed-out Profile showed the Game Center placeholder; the Cyan Your Color circle was centered; and Game Over omitted the obsolete result-status panel. Foka/Kesha placement was inspected directly; Pancake remained covered by asset validation and deterministic UI paths.
- **Behavior evidence:** structured tests cover the exact horizontal pet-facing boundaries/fallback, final menu/shop/gameplay offsets, 10% slogan shift, black Disco preview token, hidden target/rating feedback, signed-in menu rank fixture, whole-tile theme actions, Game Center placeholder, and ranked start/finish CSRF-ticket-proof contract. The final review also restored each Leaderboard result to one coherent accessibility element and made hidden feedback ignore touches.
- **Live-backend evidence:** the in-app public Arcade read returned and rendered 30 results. No authenticated ranked finish, profile, shop, or economy mutation was sent to production; automatic eligible submission is covered by the typed request-contract test.
- **Remaining checks:** physical installation and structured touch/listening review of this commit; current-batch 13 mini/13 Pro layout reruns; real Google sign-in and authenticated Arcade/shop/profile mutations; 60/120 Hz touch timing; VoiceOver, Dynamic Type, contrast, and Reduce Motion; actual Game Center design/integration; audio routes/interruptions/Silent switch; haptics; live ads; and StoreKit.
- **Evidence statement:** exact-commit SE Simulator build/regression and limited implementation-time visual/live-read evidence only; not physical-device, audio-listening, authenticated-write, Game Center, or production-release validation.

## Expanded visual-parity Simulator pass — 2026-07-17

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `bf73ecd0ec62a8862aea253ece3410f01509173a` (`feat: complete native visual parity pass`).
- **Device and OS:** named iPhone SE (3rd generation, 2022) Simulator on iOS 26.5 (23F77).
- **Configuration:** Debug; deterministic `--uitesting` fixtures for automation and final menu capture; production network mutations and real audio output disabled for automated paths; ads and StoreKit remain non-granting placeholders.
- **Parity reference:** parent SpeedyTapper web `main` commit `209ee6ca84b17bc81144d2dc60c613feeae05dc0`, plus the owner-supplied Pancake concept retained under `assets/pets/sources/chroma/`.
- **Screens/states:** fixed Light menu with logo plate and illuminated tilted slogan; public Leaderboard; signed-out and deterministic signed-in Profile; Pet Shop placement/static preview states; and Game Over score, metrics, reaction distribution, and save-status hierarchy.
- **Accessibility settings:** Simulator defaults only. Stable identifiers and labels, fixed geometry, menu scroll resistance, mode tabs, rank context, shop controls, and results sections were exercised by XCUITest; VoiceOver, Dynamic Type extremes, contrast, and Reduce Motion were not reviewed.
- **Capture:** [`SE Light menu`](evidence/2026-07-17/bf73ecd-se-light-menu.png) SHA-256 `8f1ee64a76aa698c3204961f1b8cd29a99ba3435e65ac045d96b2d289472d1ba`.
- **Automated checks:** `Scripts/check.sh` passed 29 pure Swift checks, 37 native app tests, a generic Simulator build, all 17 SE XCUITest paths, 65 committed asset hashes plus format/geometry/provenance validation, strict Swift formatting, and `git diff --check`. The final Xcode result contains 54 passed tests and zero failures.
- **Manual Simulator inspection:** the final Light menu fits without scrolling; the logo plate and illuminated slogan remain readable and unclipped. During implementation, the public Leaderboard, both Profile states, Game Over hierarchy, and Pet Shop Foka/Kesha placement were directly inspected on the same SE profile. The Pancake runtime sprite and glowing floor were inspected as image assets and reached by deterministic UI automation.
- **Behavior evidence:** structured tests cover presentation-only Perfect/Godlike millisecond events and safe randomized border lanes, surface-specific companion offsets, inner-board tap coordinates, staged wake/turn plans, static shop previews, deterministic intro/slogan tilts in UI tests, and non-shifting loading overlays. Reaction stamps were not timing-reviewed by eye on physical hardware.
- **Remaining checks:** physical installation and structured touch/listening review of this commit; current-batch 13 mini/13 Pro layout reruns; 60/120 Hz touch timing; VoiceOver, Dynamic Type, contrast, and Reduce Motion; real signed-in backend mutations; audio routes/interruptions/Silent switch; haptics; live ads; and StoreKit.
- **Evidence statement:** exact-commit SE Simulator build, regression, and limited visual evidence only; not physical-device, audio-listening, or production validation.

## Physical iPhone SE install-and-launch checkpoint — 2026-07-17

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `d3ffd87958d1eba4ca175b2e0590c1b234063072` (`fix: simplify gameplay color prompt`).
- **Device and OS:** owner's wired iPhone SE (3rd generation), iOS 26.3 (23D127); paired, trusted, and Developer Mode enabled.
- **Configuration:** Debug; automatic Apple development signing with team `APX2925X66`; bundle `com.otcsoft.pimpopom.alpha`.
- **Evidence:** the physical-device build succeeded, CoreDevice reported successful installation, and CoreDevice then reported successful application launch.
- **Scope:** confirms compilation, signing, packaging, installation, and process launch for the exact commit containing the rounded-square Your Color swatch and hidden duplicate active-target prompt.
- **Not covered:** per explicit owner request, no unit, UI, Simulator, structured visual, gameplay, touch, audio, Google, backend-mutation, accessibility, or performance retest was run for this checkpoint.
- **Evidence statement:** physical install-and-launch checkpoint only; not a structured device-tested or production-verified feature pass.

## Fixed-screen visual-parity Simulator pass — 2026-07-17

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `ec71d2169c45c7b1f3ca4d7f0434aa48d36a0314` (`feat: align native UI with web game`).
- **Devices and OS:** named iPhone SE (3rd generation, 2022), iPhone 13 mini, and iPhone 13 Pro Simulators on iOS 26.5 (23F77), run strictly one at a time.
- **Configuration:** Debug; deterministic gameplay; ephemeral `--uitesting` fixtures with production network mutations and real audio output disabled; ads and StoreKit remain non-granting placeholders.
- **Parity references:** parent SpeedyTapper commits `923a38e` for menu/theme composition, `7582b2d` for pet presentation, and `209ee6ca84b17bc81144d2dc60c613feeae05dc0` for the current 26-slogan pool. The native 10-second slogan interval is the accepted product override recorded in P-017.
- **Screens/states:** fixed Light main menu on SE and 13 mini; active Light Arcade on SE with transparent SpriteKit corners, near-full-width white board shell, custom header/HUD, Speed streak, and reserved bottom ad host; fixed Pixel main menu on 13 Pro with the 10% type increase.
- **Accessibility settings:** Simulator defaults only. Stable accessibility identifiers, labels, values, fixed geometry, scroll resistance, and glyph-off behavior were exercised by XCUITest; VoiceOver, Dynamic Type extremes, contrast, and Reduce Motion were not reviewed.
- **Captures:** [`SE Light menu`](evidence/2026-07-17/ec71d21-se-light-menu.png) SHA-256 `3bda7e5b389e603276c9be0b1f64fb1991b8dcc35ab4b9935f322b16c256c918`; [`SE Light Arcade`](evidence/2026-07-17/ec71d21-se-light-game.png) SHA-256 `beba8b4150d2ed82e9bb4377e5d07cf499b426d8abb85f038418f6701d63849f`; [`13 mini Light menu`](evidence/2026-07-17/ec71d21-13-mini-light-menu.png) SHA-256 `9e887578ae526174781d1ec642f93e3f7dcf672dc150977b585c463167a8aa03`; [`13 Pro Pixel menu`](evidence/2026-07-17/ec71d21-13-pro-pixel-menu.png) SHA-256 `d74b05dcb5bd688373fea0998e0e4c4df66a7b3227c6521404522782b441a899`.
- **Automated checks:** `Scripts/check.sh` passed 29 pure Swift checks, 33 native app tests, a generic Simulator build, all 16 SE XCUITest paths, 56 asset hashes/format/geometry/provenance checks, strict formatting, and `git diff --check`. The 33 native tests plus 15 device-independent XCUITest paths then passed separately on both 13 mini and 13 Pro.
- **Manual Simulator inspection:** Light and Pixel menus fit without scrolling on their reviewed profiles. Light has no decorative capsule bars. The Light scene is transparent around the square gameplay field, exposing the white rounded shell instead of black corners. Foka and Misha rest on their habitats in Pet Shop and remain static until tapped; the gameplay pet appears independently of the board at the requested horizontal anchor.
- **Findings:** no blocking defect in the reviewed states. The fixed menu omits build/backend/season diagnostics, keeps Remove Ads at lower right, and preserves an empty lower region rather than scrolling. The gameplay response bar drains left-to-right toward empty; the ad placeholder is below the Speed streak panel; and game-over routing silences gameplay music before menu music begins. The latter is lifecycle evidence, not listening evidence.
- **Remaining checks:** install/launch this commit on the physical SE; physical 60/120 Hz touch timing; listening across game-over/menu transitions; VoiceOver, Dynamic Type, contrast, and Reduce Motion; real signed-in backend mutations; audio routes/interruptions/Silent switch; haptics; live ads; and StoreKit.
- **Evidence statement:** Simulator-tested regression and layout evidence only; not physical-device, audio-listening, or production validation.

## Pet, audio-lifecycle, and response-bar Simulator regression pass — 2026-07-15

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `3b022c3287d41213159ecdcda39437b18e0b1c35` (`fix: restore pet audio and timer behavior`).
- **Device and OS:** named iPhone SE (3rd generation, 2022) Simulator on iOS 26.5 (23F77).
- **Configuration:** Debug; deterministic gameplay; ephemeral `--uitesting` fixtures with production network mutations disabled; authenticated pet fixture used only for server-derived Muse presentation and in-memory shop actions.
- **Parity reference:** parent SpeedyTapper web repository `main` commit `7582b2d0aed4a499796d67ae14b96e31937d543e`.
- **Screens/states:** Main Menu with Muse independently positioned and no in-flow pet icon above the mode controls; Pet Shop with sprites resting on habitats and idle previews remaining static; active Arcade with Muse and a partially drained response bar.
- **Accessibility settings:** Simulator defaults only. Stable accessibility identifiers and progress values were exercised by XCUITest; VoiceOver, Dynamic Type extremes, contrast, and Reduce Motion were not reviewed.
- **Ads/StoreKit/auth:** disabled ad and StoreKit placeholders; deterministic local authenticated-pet fixture; no production purchase, coin, selection, or ranked mutation.
- **Captures:** [`SE menu special Muse`](evidence/2026-07-15/3b022c3-se-menu-muse.png) SHA-256 `3a39f6e82a90eb1228ca75c9f7c2f40ed539730b90d08e6d4ad9bf9e3f45bde9`; [`SE Pet Shop habitat/static preview`](evidence/2026-07-15/3b022c3-se-pet-shop.png) SHA-256 `d8c521d76756226c04003f2a664b51216031f34fc5b2bcd2a4739826b3ccb0f3`; [`SE Arcade Muse/response bar`](evidence/2026-07-15/3b022c3-se-arcade-muse.png) SHA-256 `a4226a1366e2b314fd82095ab8eeb100ff67f0bd66ff634468066d87ac3db53f`.
- **Automated checks:** 29 pure Swift checks, 26 native unit tests, generic iOS Simulator build, and nine SE XCUITest paths passed through `Scripts/check.sh`; 47 retained runtime/master/source files passed committed hash and format/dimension validation.
- **Manual Simulator inspection:** the menu pet stays clear of the mode controls; approved shop sprites align with their habitats; a recorded Foka preview remained static before the tap, moved through non-resting frames once, and returned to rest; the Arcade response fill was visibly partial and left-anchored.
- **Findings:** no blocking defect in the reviewed states. The menu pet no longer occupies the mode layout; approved shop sprites align with their habitats and animate only after a tap; Select → Hide → Show state updates in the shop; selected/visible/special-pet resolution reaches menu and gameplay; and the active Arcade response bar drains rather than growing. Gameplay terminal events route music to silence before menu routing, but this automated Simulator pass is not listening evidence.
- **Remaining checks:** physical-device install/launch of this commit; listening confirmation across game-over/menu transitions; 60/120 Hz touch timing; VoiceOver, Dynamic Type, contrast, and Reduce Motion; real signed-in backend mutations; audio routes/interruptions/Silent switch; haptics; live ads; and StoreKit.
- **Evidence statement:** Simulator-tested regression and layout evidence only; not physical-device, audio-listening, or production validation.

## Physical iPhone SE cosmetics/audio install checkpoint — 2026-07-15

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `54bd3720d22e42dfd88dc8c1ef7d660f63a6ae7a` (`feat: port cosmetics economy and audio`).
- **Device and OS:** owner's iPhone SE (3rd generation, 2022), iOS 26.3.
- **Configuration:** Debug; automatic Apple development signing; team `APX2925X66`; bundle `com.otcsoft.pimpopom.alpha`; USB trusted and Developer Mode enabled.
- **Evidence:** a clean physical-device build succeeded, and CoreDevice reported successful installation of the signed app bundle. The immediate automatic-launch request was denied because the phone was locked.
- **Scope:** confirms compilation, signing, packaging, and installation of the cosmetics/economy/audio checkpoint.
- **Not covered:** application launch or listening/touch review of this checkpoint; Google sign-in; authenticated theme/pet purchases; reaction timing; audio latency/balance/Silent switch/routes; accessibility; 13 mini/13 Pro hardware.
- **Evidence statement:** physical installation checkpoint only; not launch-tested, device-tested, or production-verified.

## Physical iPhone SE install checkpoint — 2026-07-15

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `fd34cf4c3d854486c236aa9edcca9c721495804f` (`feat: add PimPoPom alpha app icon`).
- **Device and OS:** owner's iPhone SE (3rd generation, 2022), iOS 26.3.
- **Configuration:** Debug; automatic Apple development signing; bundle `com.otcsoft.pimpopom.alpha`; USB trusted and Developer Mode enabled.
- **Evidence:** the app was installed and launched through the local Xcode/CoreDevice path after development trust was confirmed. The owner reported that this version was working.
- **Scope:** confirms install, signing, launch, the internal icon, and basic playability of the earlier gameplay checkpoint. No capture set or structured session was recorded.
- **Not covered:** current Theme Shop/Pet Shop/coins/audio slice; Google sign-in; authenticated economy or ranked writes; reaction timing; 10-minute stability; audio listening/Silent switch/routes; accessibility; 13 mini/13 Pro hardware.
- **Evidence statement:** physical install-and-launch checkpoint only; not a full device-tested feature pass and not production-verified.

## Internal alpha Simulator pass — 2026-07-15

- **Candidate/version/build:** PimPoPom 0.1.0 (1).
- **Implementation commit:** `6fbc6d3c9c537e11a0a8f4a0af25872d73febbef` (`feat: port playable native alpha`).
- **Devices and OS:** iPhone SE (3rd generation), iPhone 13 mini, and iPhone 13 Pro Simulator profiles on iOS 26.5 (23F77).
- **Configuration:** Debug; deterministic game launch; ephemeral signed-out `--uitesting` backend fixture with networking disabled.
- **Screens/states:** SE Main Menu; active Zen target on 13 mini and 13 Pro; compact HUD/board; End run; Speed streak; bottom disabled-ad host; lower-right disabled Remove Ads control.
- **Accessibility settings:** Simulator defaults only. Identifiers were exercised by XCUITest; VoiceOver, Dynamic Type extremes, contrast, and motion settings were not reviewed.
- **Ads/StoreKit/auth:** no vendor SDK or product; disabled placeholders; signed out. No production mutation was possible from the capture configuration.
- **Captures:** [`SE menu`](evidence/2026-07-15/6fbc6d3-se-menu.png) SHA-256 `e573c5729d91253a5db8b16ee2b7ca8216b2bc98de678e708fe15265ba037fea`; [`13 mini Zen`](evidence/2026-07-15/6fbc6d3-13-mini-zen.png) SHA-256 `6afcba421b21e3328d87a511a89d2fc6350802cf9d1158a3a4f3563e642230e0`; [`13 Pro Zen`](evidence/2026-07-15/6fbc6d3-13-pro-zen.png) SHA-256 `5c42c981cb8a398ef09af84ea630d414a957a347c59e3b112409c5e5b1511c35`.
- **Automated checks:** 29 pure Swift checks, generic iOS Simulator build, and two SE XCUITest smoke paths passed through `Scripts/check.sh` before the implementation commit.
- **Findings:** no blocking layout defect in the reviewed states. The gameplay ad host remains below the Speed streak meter on both notched profiles. The SE menu is intentionally scrollable; its build label needs a small scroll to be fully visible while Remove Ads remains in the lower-right safe layout.
- **Remaining checks:** physical SE install/signing, physical 60/120 Hz touch timing and SpriteKit cadence, accessibility matrix, signed-in Google/ranked proof, network races, audio/haptics, live ads, and StoreKit.
- **Evidence statement:** Simulator-tested layout and smoke flows only; not device-tested or production-verified.

## Initial acceptance checklist

- PimPoPom name/logo is used on every player-facing surface; no legacy product name leaks into app metadata or screenshots.
- Main-menu Remove Ads occupies the lower-right safe layout with a 44×44-point minimum target.
- Theme Shop and Pet Shop each expose the same Buy Coins flow.
- The ad host is at the absolute bottom of gameplay, below the Speed streak meter (the requested “speed rating bar”) and above the safe area.
- Ad fill/no-fill/removal never shifts the board during a run.
- No banner overlaps or accepts gameplay taps; active-run fill follows the accepted policy.
- 1×1, 2×2, and 4×4 targets remain visually unambiguous on the smallest supported iPhone.
- Dynamic Type, VoiceOver, color-blind glyphs, Increase Contrast, and Reduce Motion remain usable.
- All themes preserve target/decoy semantics and rating/meter readability.
- Pet/habitat art never enters the reaction board; hidden pets appear nowhere.
- StoreKit price, pending, failed, restored, refunded, and insufficient-funds states are legible and nonmanipulative.
- Consent, privacy options, account linking, and deletion are findable.

## Entry template

```text
Candidate/version/build:
Commit:
Device/Simulator and OS:
Configuration/environment:
Screens/states reviewed:
Accessibility settings:
Ads/StoreKit/auth mode:
Captures:
Automated checks:
Findings and severity:
Remaining physical-device or production checks:
Final evidence statement:
```
