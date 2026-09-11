# Design QA

## Build 29 — partial Simulator evidence

The iPhone 17 focused run passed four-player badge layout and waiting-room privacy,
but clock-stamp feedback failed before its final container correction. Initial
tutorial recordings exposed accessibility identity/button defects, corrected in
`b3b1473`; final `199bf48` also uses a stable stamp host. The owner requested no
further Simulator rechecks. These corrections, compact/all-theme tutorials and
pickup presentation remain QA items, not verified visual fixes.

Evidence: `build/releases/build29-20260911/qa-status.md`, the initial/focused
xcresults and retained attachments. Archive inspection is not visual acceptance.

## Historical build 28 baseline

Build 28's iPhone 17 / iOS 26.5 Simulator gate covered all four themes, multiplayer
board/spectator/navigation states, room search/private creation and code controls.
A separate compact iPhone SE gate passed all four themed hub/waiting screens,
including Copy and reachable Leave/Ready/Start with a scrolling four-player roster.
Eight compact screenshots were inspected; themed rewind-clock attachments were
also reviewed. Exact evidence and initial Simulator failures are retained in
`build/releases/build28-20260911/`. Historical build-24/21 captures are not current
release evidence or physical-device acceptance.

## Physical acceptance still required

- Physical iPhone review of build 29 on compact/tall 60 Hz and ProMotion layouts.
- Real 2-, 3-, and 4-player waiting/live/results states with distinct accounts.
- Long/localized names, largest supported text, VoiceOver, bold text, Increase
  Contrast, Reduce Motion, and glyph-off review in every theme.
- Dynamic v2 network/reconnect/result states; FAST is no longer a live implementation.
- Final App Store screenshots from the submitted production-facing build. The
  retained launch kit uses older build-6 captures and is source/provenance only.

Record exact commit/build, device/OS, configuration, scenario, theme, accessibility
settings, artifact path/hash, result, and remaining limitations.
