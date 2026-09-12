# Design QA

## Build 30 — compact results and menu

Final binary source `79b02abc524954547fc49b5f67ca3d587f121c41` implements the owner's
revised layout: a centered 32-point coin above the large earned amount, both above
the player roster. Below 700 points of available height, the result badge/title
and header spacing shrink. Seconds carry is hidden; the receipt amount and
Leaderboard/Menu remain visible while the roster scrolls. Pixel trophy/profile
icons match the theme, and mode names are centered without subtitles. The owner
reviewed the UI, said it looked good and approved both-group TestFlight deployment.

All eight final captures in `build/releases/build30-20260912/compact-attachments/`
were reviewed using its manifest: Default, Disco, Light and Pixel, with two and
four players on the iPhone SE (3rd generation) Simulator profile, iOS 26.5,
750×1334. The compact reward scenarios passed. No header/reward/button clipping
or overlap was found. Pixel's fourth row extends below the scroll viewport;
existing compact non-Pixel name/stat truncation is unchanged. The manual final
Pixel menu capture also shows the requested icons and centered labels.

The menu test's first compact failure was a nested-staticText query assumption,
corrected in the test without a product layout change. The final full test run was
explicitly stopped by the owner: 259 passed, three failed, one skipped. Failures
include an unresolved all-theme tutorial wait timeout as well as termination and
test-runner device errors. This visual acceptance and focused evidence are not
a fully passing final UI gate. Earlier below-roster compact captures are
superseded. See [TESTING](TESTING.md) and the build-30 `verification-notes.md`.

## Build 29 — partial Simulator evidence, historical

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

- Physical iPhone review of build 30 on compact/tall 60 Hz and ProMotion layouts.
- Real 2-, 3-, and 4-player waiting/live/results states with distinct accounts.
- Long/localized names, largest supported text, VoiceOver, bold text, Increase
  Contrast, Reduce Motion, and glyph-off review in every theme.
- Dynamic v2 network/reconnect/result states; FAST is no longer a live implementation.
- Final App Store screenshots from the submitted production-facing build. The
  retained launch kit uses older build-6 captures and is source/provenance only.

Record exact commit/build, device/OS, configuration, scenario, theme, accessibility
settings, artifact path/hash, result, and remaining limitations.
