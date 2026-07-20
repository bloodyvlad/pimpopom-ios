# Optional App Preview — 25-second shot list

Apple App Preview video is optional. The safest version is a clean portrait screen recording of the submitted build with short deterministic overlays. Keep the UI understandable with sound muted because product-page previews autoplay silently.

## Capture target

- Duration: 25 seconds; Apple permits 15–30 seconds.
- Suggested portrait master: 886×1920, H.264, progressive, High Profile up to level 4.0, 10–12 Mbps, no more than 30 fps.
- Audio if used: AAC stereo, 256 kbps, 44.1 or 48 kHz. Keep music licensed and make the story work without it.
- Capture only actual PimPoPom UI. Captions, touch indicators, and narration may be added afterward; do not simulate unimplemented gameplay.
- Use a clean fictional profile and stable status-bar state. Hide notifications, personal data, test labels, debug menus, and purchase credentials.

## Timeline

| Time | Actual app capture | Overlay | Audio idea |
| --- | --- | --- | --- |
| 0:00–0:02 | Main menu, logo and three launch rules | `TINY TAPS. GIANT SCORES.` | Short Pim–Po–Pom launch cue |
| 0:02–0:06 | Start Arcade; first clean target tap | `TAP YOUR COLOR` | One crisp tap tone |
| 0:06–0:10 | Faster board state with points/rating feedback and Speed Bar movement | `EVERY MILLISECOND MATTERS` | Quick four-note tap sequence |
| 0:10–0:12 | One deliberate miss and visible life change | `KEEP YOUR FOCUS` | Existing “oops” cue |
| 0:12–0:16 | Zen with rainbow Any target and several relaxed taps | `FIND YOUR FLOW` | Softer theme loop |
| 0:16–0:19 | Theme Shop: tap Default → Light → Pixel/Disco tiles | `SWITCH UP YOUR STYLE` | Three light UI cues |
| 0:19–0:22 | Menu companion followed by current Leaderboard | `CHASE YOUR BEST` | Small rising accent |
| 0:22–0:25 | Return to live menu/logo; keep it inside actual app capture | `PimPoPom` / `Tap fast. Find your flow.` | Pim–Po–Pom resolve |

## Recording checklist

- [ ] Record on a device size supported by the selected App Preview slot.
- [ ] Use the exact submitted build and current production-facing feature set.
- [ ] Show no fake ad/test-mode banner and no unreleased screen.
- [ ] Avoid prices unless they come directly from localized StoreKit in the captured storefront.
- [ ] Make touch locations legible without adding a fake hand/device render.
- [ ] Keep all feature captions within safe margins and on screen long enough to read.
- [ ] Check the encoded file locally, upload, then watch App Store Connect’s processed preview end to end.
