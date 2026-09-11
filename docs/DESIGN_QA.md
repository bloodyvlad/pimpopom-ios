# Design QA

Build 28's iPhone 17 / iOS 26.5 Simulator gate covers all four themes, multiplayer
board/spectator/navigation states, room search/private creation and code controls.
A separate compact iPhone SE gate passed all four themed hub/waiting screens,
including Copy and reachable Leave/Ready/Start with a scrolling four-player roster.
Eight compact screenshots were inspected; themed rewind-clock attachments were
also reviewed. Exact evidence and initial Simulator failures are retained in
`build/releases/build28-20260911/`. Historical build-24/21 captures are not current
release evidence or physical-device acceptance.

## Physical acceptance still required

- Physical iPhone review of build 28 on compact/tall 60 Hz and ProMotion layouts.
- Real 2-, 3-, and 4-player waiting/live/results states with distinct accounts.
- Long/localized names, largest supported text, VoiceOver, bold text, Increase
  Contrast, Reduce Motion, and glyph-off review in every theme.
- Dynamic v2 network/reconnect/result states; FAST is no longer a live implementation.
- Final App Store screenshots from the submitted production-facing build. The
  retained launch kit uses older build-6 captures and is source/provenance only.

Record exact commit/build, device/OS, configuration, scenario, theme, accessibility
settings, artifact path/hash, result, and remaining limitations.
