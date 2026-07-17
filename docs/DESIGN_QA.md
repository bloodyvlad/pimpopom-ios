# Design QA history

This file is historical evidence, not proof of the current TestFlight or App Store release. Every entry must identify the exact PimPoPom commit, version/build, device or Simulator, OS, configuration, and capture paths.

## Current evidence

The playable Xcode alpha has current expanded visual-parity evidence on the named iPhone SE 2022 Simulator at implementation commit `bf73ecd`, with earlier three-profile fixed-screen evidence retained at `ec71d21`. Follow-up implementation commit `d3ffd87`, which removes the redundant visible active-target prompt and changes the Your Color swatch to a rounded square, was development-signed, installed, and launched successfully on the owner's physical iPhone SE with iOS 26.3. Per owner request, it was not retested. The current `bf73ecd` batch was not installed on physical hardware, and the 13 mini/13 Pro profiles were not rerun for it. No physical 13 mini/13 Pro, TestFlight, or App Store QA has been performed; no Simulator result validates 60/120 Hz touch timing.

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
