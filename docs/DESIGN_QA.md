# Design QA history

This file is historical evidence, not proof of the current TestFlight or App Store release. Every entry must identify the exact PimPoPom commit, version/build, device or Simulator, OS, configuration, and capture paths.

## Current evidence

No PimPoPom Xcode UI or visual asset exists yet. No visual, physical-device, TestFlight, or App Store QA has been performed.

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
