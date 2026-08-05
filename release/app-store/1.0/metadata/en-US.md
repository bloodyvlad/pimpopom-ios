# English (U.S.) App Store metadata draft

Status: current copy draft; no production App Store submission. Retained screenshot
PNGs in this folder show build 6 and must be recaptured from the final candidate.

## Product page

**Name:** PimPoPom

**Subtitle:** A Color Reaction Challenge

**Promotional text:** Quick taps, glowing themes, playful companions, and live
Multiplayer. Chase Arcade scores, race friends, or unwind in endless Zen.

**Keywords:**
`reflex,tap,speed,arcade,zen,multiplayer,leaderboard,casual,focus,timing,pets,themes`

**Categories:** Games — Casual (primary); Games — Arcade (secondary)

**Price / initial territories:** Free; United States and Canada

## Description

How fast can you find your color?

PimPoPom is a bright reaction game built around quick taps, precise timing, and
one-more-run score chasing. Watch the board, tap the right cell, avoid decoys, and
protect your three lives as the challenge grows.

THREE WAYS TO PLAY

• Arcade — React before time runs out, build multipliers with your fastest hits,
and chase the leaderboard.

• Zen — Endless, unranked practice with no lives, deadlines, or coin rewards.

• Multiplayer — Join two to four players, hit only your assigned color, and compete
for a protocol-verified, peer-consistent result. Multiplayer awards no coins or
achievements and requires a PimPoPom profile plus Game Center.

FEEL EVERY TAP

See the points and rounded reaction time for every correct hit. Godlike and Perfect
reactions charge the Speed Bar toward larger multipliers. Wrong, late, or empty
taps reset the boost in Arcade.

MAKE IT YOURS

• Switch among Default, Disco, Light, and Pixel styles.

• Unlock companions and choose who joins your menu, game, and leaderboard.

• Complete achievements, collect coin rewards, choose color glyphs, control music
and Sound FX, and select your Home Screen icon.

PLAY NOW OR CONNECT

Arcade and Zen are available without signing in. A profile is required for ranked
Arcade, durable achievements/coins/cosmetics, purchases, and Multiplayer. Optional
coin packs also grant account-bound ad-free access. The standalone Remove Ads
purchase is restorable and supports Family Sharing.

Tap your color. Find your rhythm. See how fast you can go.

## Required new screenshot plan

1. Tiny taps. Giant Arcade scores.
2. Every millisecond matters.
3. Two to four players. One fast match.
4. Find your flow in Zen.
5. Switch themes and companions.
6. Chase Arcade and Multiplayer leaderboards.

Capture these only from the final submitted build with fictional test data and no
debug/Test-mode/private information.

## TestFlight build 20 copy

**Beta App Description**

PimPoPom is a reaction game with Arcade, Zen, and a 2–4-player Multiplayer beta.
This build makes Multiplayer players easier to recognize and improves Pixel-theme
readability throughout the waiting and selection flow.

**What to Test**

Multiplayer!!!

Using two to four distinct Game Center and PimPoPom accounts, create or join the
same lobby. Confirm every waiting row shows the selected pet facing half-right, a
readable public name/readiness state, and a square assigned-color cell. Toggle
Glyphs and verify those cells update.

Start a match and verify the horizontal badges below the Speed Bar retain pet,
assigned-color outline/glow, score, name, multiplier, and leader crown in Classic,
Disco, Light, and Pixel. Check Pixel supporting copy, theme-styled waiting-room back
control, and Leaderboard habitat alignment for Foka/Kesha. Finish with creator and
joined-player winners; verify terminal Results and eligible Multiplayer rows. Report
roster/settlement stalls, clipped text, incorrect pets/colors/glyphs, purchase
errors, or ads shown to ad-free accounts.

**Beta Review Notes**

Sign-in is optional for Arcade and Zen. Multiplayer requires a signed-in profile,
confirmed nickname, and current Game Center player. PHP owns authenticated lobbies
and protocol-verified peer-consistent settlement; GameKit carries live peer traffic.
Multiplayer awards no coins or achievements. Purchases use TestFlight Sandbox and
advertising uses AdMob behind UMP. iOS does not submit Game Center scores or
achievements directly.

## Production App Review notes draft

PimPoPom can be evaluated signed out through Arcade and Zen. Ranked Arcade,
profile-bound progression, purchases, and Multiplayer require the documented
identity gates.

- Review account: **[ADD SECURELY IN APP STORE CONNECT — NEVER COMMIT]**
- Review path: Main Menu → Profile; Main Menu → Coins/Remove Ads; Profile → Delete
  Account; Main Menu → Multiplayer for multi-device testing.
- Multiplayer needs two to four distinct Game Center/PimPoPom accounts and devices.
- The standalone Remove Ads product is non-consumable, restorable, and
  Family-Shareable. Coin packs are consumable and reconciled server-side.

## Required URLs and ownership

- Support URL: **[PUBLISH AND ADD]**
- Privacy Policy URL: **[PUBLISH AND ADD]**
- Terms URL: **[PUBLISH AND ADD]**
- Account-deletion help URL: **[PUBLISH AND ADD]**
- Marketing URL: optional; **[ADD IF READY]**
- Copyright: `2026 [CONFIRMED RIGHTS-OWNING ENTITY]`
