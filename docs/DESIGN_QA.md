# Design QA history

This file is historical evidence, not proof of the current TestFlight or App Store release. Every entry must identify the exact PimPoPom commit, version/build, device or Simulator, OS, configuration, and capture paths.

## Current evidence

The playable Xcode alpha has Simulator evidence on iOS 26.5 for the named iPhone SE 2022, iPhone 13 mini, and iPhone 13 Pro profiles. The exact implementation commit and final capture paths are recorded in the dated entry added after the tested source commit. No physical-device, TestFlight, or App Store QA has been performed; no Simulator result validates 60/120 Hz touch timing.

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
