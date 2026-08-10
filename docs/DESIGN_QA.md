# Current design QA evidence

This file keeps only evidence relevant to the current TestFlight presentation.
Earlier checkpoints and screenshot paths remain in Git history. Evidence here does
not override `CURRENT_VERSION.md` or prove physical-device behavior.

## TestFlight 1.02 (21) — 2026-08-10

- Exact archive source: `66ffd0b3687d198682e85aa4bfcf40ac4dcbb88d`.
- The named iPhone 17 Simulator gate passed 272/272 native tests.
- Current Classic, Disco, Light, and Pixel captures show the straight borderless
  `+points` / `Rating • ms` glow on the tapped target.
- The Pixel Multiplayer back button passed a lower-right-edge tap inside its full
  44-point hit region.

## Still required

- Physical iPhone review of build 21 on compact/tall 60 Hz and ProMotion layouts.
- Real 2-, 3-, and 4-player waiting/live/results states with distinct accounts.
- Long/localized names, largest supported text, VoiceOver, bold text, Increase
  Contrast, Reduce Motion, and glyph-off review in every theme.
- Dynamic network/reconnect/settlement states and FAST predicted/reconciled states.
- Final App Store screenshots from the submitted production-facing build. The
  retained launch kit uses older build-6 captures and is source/provenance only.

For a new visual checkpoint record exact commit/build, Simulator/device/OS,
configuration, scenario, theme, accessibility settings, artifact path/hash, what
was inspected, result, and remaining limitations.
