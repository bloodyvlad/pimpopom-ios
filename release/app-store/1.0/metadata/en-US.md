# English (U.S.) App Store metadata draft

## Product page

**Name**

PimPoPom

**Subtitle — 26/30 characters**

A Color Reaction Challenge

**Promotional text — 134/170 characters (136 UTF-8 bytes)**

Quick taps, glowing themes and playful companions. Chase your best Arcade score or unwind in endless Zen—one colorful round at a time.

**Keywords — 94/100 ASCII bytes**

reflex,tap,speed,arcade,zen,leaderboard,casual,focus,coordination,timing,precision,pets,themes

**Primary category**

Games — Casual

**Secondary category**

Games — Arcade

**Price**

Free

**Initial territories**

United States and Canada

## Description

How fast can you find your color?

PimPoPom is a bright reaction game built around quick taps, precise timing, and one-more-run score chasing. Watch the board, tap the right cell, avoid decoys, and protect your three lives as the challenge grows.

TWO WAYS TO PLAY

• Arcade — React before time runs out, build multipliers with your fastest hits, and chase your best score.

• Zen — Endless, unranked practice with no lives, deadlines, or coin rewards. Settle in and find your flow.

FEEL EVERY TAP

See the points and rounded reaction time for every correct hit. Godlike and Perfect reactions charge the Speed Bar toward bigger multipliers. Wrong, late, or empty-board taps reset the boost in Arcade.

MAKE IT YOURS

• Switch among Default, Disco, Light, and Pixel styles.

• Unlock companions and choose who joins your menu, game, and leaderboard.

• Complete achievements and collect coin rewards.

• Personalize music, sound effects, glyphs, and the Home Screen icon.

PLAY NOW OR CONNECT

Local Arcade and Zen are available without signing in. Sign in and confirm a public nickname to submit eligible Arcade scores, claim achievements, keep your coins and cosmetics connected to your profile, and use in-app purchases.

Optional coin packs and a standalone Remove Ads purchase are available. Coin-pack purchases also grant account-bound ad-free access. The standalone Remove Ads purchase is restorable and supports Family Sharing.

Tap your color. Find your rhythm. See how fast you can go.

## Screenshot order

1. Tiny taps. Giant scores.
2. Every millisecond matters.
3. Find your flow in Zen.
4. Switch up your style.
5. Chase the Arcade leaderboard.
6. Your game, all in one place.

## Build 6 TestFlight copy

**Beta App Description**

PimPoPom is a reaction game with Arcade and Zen modes. This beta tests gameplay, StoreKit coin purchases, account management, consent handling, and advertising.

**What to Test**

Test Arcade and Zen gameplay, banner placement, the interstitial after every 3 eligible completed rounds, sandbox coin purchases, ad removal and purchase restoration, Privacy Choices, and account deletion. Please report crashes, layout problems, purchase errors, or ads shown to ad-free accounts. Minor Pixel Theme fixes are also included.

**Beta Review Notes**

Purchases use Apple’s TestFlight Sandbox environment. Advertising uses Google AdMob. The gameplay banner is placed in a fixed bottom area separated from the gameplay zone by the Speed Bar. The interstitial becomes due after 3 eligible completed rounds and is attempted from Results. Sign-in is optional and the app can be evaluated without reviewer-provided credentials.

## Build 7 / version 1.02 TestFlight copy

**Beta App Description**

PimPoPom is a reaction game with Arcade and Zen modes. Version 1.02 adds Sign in with Apple and explicit Apple, Google, and Game Center profile linking while preserving optional signed-out play.

**What to Test**

Test Sign in with Apple login and separately confirmed registration, linking Apple to an existing Google-backed PimPoPom profile, provider reauthentication, Game Center Connect/Verify/Turn Off, and account deletion. Also test Arcade and Zen gameplay, banner placement, the interstitial after every 3 eligible completed rounds, sandbox coin purchases, ad removal, purchase restoration, and Privacy Choices. Please report account-link conflicts, unexpected profile or wallet changes, crashes, layout problems, purchase errors, or ads shown to ad-free accounts.

**Beta Review Notes**

Sign-in is optional and the app can be evaluated without reviewer-provided credentials. Sign in with Apple and Google are primary PimPoPom identity methods. The app never merges accounts automatically: an existing player must sign in to that profile first and explicitly link another provider. Game Center is optional, link-only in this build, and does not create or access a PimPoPom wallet; scores and achievements are not yet published to Game Center. Purchases use Apple’s TestFlight Sandbox environment. Advertising uses Google AdMob. The gameplay banner is fixed below the Speed Bar, and the interstitial becomes due after 3 eligible completed rounds and is attempted from Results.

## Build 8 / version 1.02 TestFlight copy

**Beta App Description**

PimPoPom is a reaction game with Arcade and Zen modes. Version 1.02 adds Sign in with Apple and explicit Apple, Google, and Game Center profile linking while preserving optional signed-out play.

**What to Test**

Test banner visibility on the Main Menu, during Arcade and Zen gameplay, and on Results. On the registered owner device, production-unit no-fill should fall back to a Google demo creative; other testers use Google demo units directly. Also test Privacy Choices, the interstitial after every 3 eligible completed rounds, Sign in with Apple, account linking, sandbox coin purchases, ad removal, purchase restoration, and account deletion. Please report missing ads, repeated consent prompts, ads shown to ad-free accounts, crashes, layout problems, purchase errors, or unexpected profile or wallet changes.

**Beta Review Notes**

Sign-in is optional and the app can be evaluated without reviewer-provided credentials. Purchases use Apple’s TestFlight Sandbox environment. Advertising uses Google AdMob behind Google UMP consent. This named QA build uses Google’s official demo inventory for ordinary testers; one registered owner test device may first exercise the app’s production ad units in Google Test mode and falls back to the official demo units after a no-fill response. The gameplay banner is fixed below the Speed Bar, and the interstitial becomes due after 3 eligible completed rounds and is attempted from Results. Sign in with Apple and Google are primary PimPoPom identity methods; accounts are never merged automatically. Game Center is optional and link-only, and does not create or access a PimPoPom wallet.

## Build 11 / version 1.2 TestFlight copy

**Beta App Description**

PimPoPom is a reaction game with Arcade and Zen modes. Version 1.2 tests fresh Game Center player verification and direct access to Apple’s Game Center statistics while preserving optional signed-out play, StoreKit, account management, consent handling, and advertising.

**What to Test**

Create or sign in to a PimPoPom profile with Apple or Google, then open Profile and connect Game Center. Confirm that Connect/Verify completes against the Game Center player currently active on the device. Use **See Stats** to open Apple’s dashboard, complete a protocol-verified Arcade run, and confirm that the global Arcade leaderboard and unlocked achievements appear after server publication and Apple propagation. Also test Turn Off, reconnect, Apple account switching, Arcade and Zen gameplay, audio after background/foreground transitions, banner/interstitial ads, Sandbox coin purchases, ad removal and restoration, Privacy Choices, and account deletion. Report conflicts, missing statistics, hangs, crashes, silent audio, purchase errors, or ads shown to ad-free accounts.

**Beta Review Notes**

Sign-in is optional and the app can be evaluated without reviewer-provided credentials. Game Center requires a signed-in PimPoPom profile and explicit Connect; it cannot create or access a wallet. The app obtains fresh GameKit identity proof, while the PimPoPom PHP service asynchronously publishes only protocol-verified Arcade personal bests and authoritative achievement unlocks. The client never submits scores or achievements directly, so Apple’s dashboard may update after a short propagation delay. Purchases use Apple’s TestFlight Sandbox environment. Advertising uses Google AdMob behind Google UMP consent. The gameplay banner is fixed below the Speed Bar, and the interstitial becomes due after 3 eligible completed rounds and is attempted from Results.

## Build 17 / version 1.02 TestFlight copy

**Beta App Description**

PimPoPom is a reaction game with Arcade, Zen, and a 2–4-player Multiplayer beta. This build corrects Multiplayer waiting-room readiness and polishes leaderboards, Pixel presentation, and player-name layout.

**What to Test**

Using two or more distinct Game Center and PimPoPom accounts, create or join the same Multiplayer lobby. Confirm every participant can toggle Ready while the GameKit roster is still connecting, but only the creator can start and only after the complete roster is confirmed and all players are ready. Verify the shared Arcade, Zen, and Multiplayer Leaderboard tabs, one back control, readable waiting-room names, Pixel labels without duplicate shadows, eliminated-player spectating, synchronized play, and final settlement. Also report crashes, roster stalls, purchase errors, layout problems, or ads shown to ad-free accounts.

**Beta Review Notes**

Sign-in is optional for Arcade and Zen. Multiplayer requires a signed-in PimPoPom profile with a confirmed nickname and the Game Center player active on the device. PimPoPom uses PHP for authenticated lobbies and verified settlement while GameKit carries live peer-to-peer gameplay. Multiplayer awards no coins or achievements. Purchases use Apple’s TestFlight Sandbox environment, and advertising uses Google AdMob behind Google UMP consent. The client does not submit Game Center scores or achievements directly; the PHP service publishes eligible verified results asynchronously.

## Build 18 / version 1.02 TestFlight copy

**Beta App Description**

PimPoPom is a reaction game with Arcade, Zen, and a 2–4-player Multiplayer beta. This build fixes Multiplayer finish and settlement reliability, then streamlines the waiting room, live HUD, Speed Bar, and stacked player badges across iPhone sizes.

**What to Test**

Multiplayer!!!

Using two or more distinct Game Center and PimPoPom accounts, create or join the same Multiplayer lobby. Confirm the PimPoPom MP header replaces the old “Available games,” “Own your color,” and duplicate roster-loading block; players appear in one stacked list; and Start match shows “Waiting for players” or “Loading roster…” until the complete roster is found and every player is ready, then becomes active only for the creator.

Start a match and verify the compact top HUD, normal pet-free Speed Bar, and full-width player badges below the play area. Each badge should fit one row with the pet at left, score and small player name centered, large multiplier at right, and the leader crown over the top-right corner. On iPhone SE, confirm the game zone sits closer to the HUD and a four-player waiting room keeps its controls visible; on larger iPhones, confirm spacing remains balanced.

Finish matches with both the creator and a joined player winning. Verify eliminated players spectate to the end, every device reaches terminal Results, both exact transcripts are accepted, and every verified participant result appears in the Multiplayer leaderboard. Report crashes, roster stalls, stuck “Checking every player” states, missing results, clipped or overlapping text, incorrect crowns or scores, purchase errors, or ads shown to ad-free accounts.

**Beta Review Notes**

Sign-in is optional for Arcade and Zen. Multiplayer requires a signed-in PimPoPom profile with a confirmed nickname and the Game Center player active on the device. PimPoPom uses PHP for authenticated lobbies and protocol-verified, peer-consistent settlement while GameKit carries live peer-to-peer gameplay. Multiplayer awards no coins or achievements. Purchases use Apple’s TestFlight Sandbox environment, and advertising uses Google AdMob behind Google UMP consent. The client does not submit Game Center scores or achievements directly; the PHP service publishes eligible verified results asynchronously.

## Build 19 / version 1.02 TestFlight copy

**Beta App Description**

PimPoPom is a reaction game with Arcade, Zen, and a 2–4-player Multiplayer beta. This build polishes the Multiplayer waiting room, live HUD, game-zone spacing, Speed Bar, and four-player presentation across every theme.

**What to Test**

Multiplayer!!!

Using two to four distinct Game Center and PimPoPom accounts, create or join the same Multiplayer lobby. Confirm the waiting room contains no pets, every player row uses the same full-size design, the roster begins lower below the PimPoPom MP header, and Ready/Start controls remain fully visible and usable.

Start a match and verify Points and Lives are compact while the larger center card clearly shows the assigned-color cell and color name without a Your Color caption. The game zone should begin 5 points below the HUD. Confirm the normal pet-free Speed Bar appears below the game zone.

With two, three, and four players, confirm all player badges remain in one horizontal row below the Speed Bar. Each smaller badge should show a vertically centered pet, score, public name, one-line multiplier, thicker assigned-color outline and visible glow; the current leader's crown should overlay its upper-right corner. Check Classic, Disco, Light, and Pixel themes. Also finish matches with both creator and joined-player winners, verify eliminated-player spectating, terminal Results, accepted transcripts, and Multiplayer leaderboard rows. Report crashes, roster stalls, stuck settlement, clipped or overlapping text, incorrect crowns or scores, purchase errors, or ads shown to ad-free accounts.

**Beta Review Notes**

Sign-in is optional for Arcade and Zen. Multiplayer requires a signed-in PimPoPom profile with a confirmed nickname and the Game Center player active on the device. PimPoPom uses PHP for authenticated lobbies and protocol-verified, peer-consistent settlement while GameKit carries live peer-to-peer gameplay. Multiplayer awards no coins or achievements. Purchases use Apple's TestFlight Sandbox environment, and advertising uses Google AdMob behind Google UMP consent. The client does not submit Game Center scores or achievements directly; the PHP service publishes eligible verified results asynchronously.

## Production App Review notes draft

PimPoPom can be evaluated without signing in: launch the app, choose Arcade or Zen, and play immediately. Arcade leaderboard submission, profile-bound cosmetics, achievements, and StoreKit value require a signed-in PimPoPom profile.

To review account-bound purchases and ranked submission, use the demo account below or follow the attached reviewer instructions:

- Demo account: **[ADD REVIEW ACCOUNT]**
- Password or sign-in method: **[ADD SECURELY IN APP STORE CONNECT — NEVER COMMIT]**
- Review path: Main Menu → Profile to sign in; Main Menu → Coins or Remove Ads for StoreKit; Profile → Delete Account for in-app deletion.

The standalone Remove Ads product is non-consumable, restorable, and Family-Shareable. Coin packs are consumable and are reconciled by the PimPoPom server after local StoreKit verification. Do not include real credentials in this repository.

## First-release notes

“What’s New” is not shown for the first App Store version. Keep this for TestFlight or a later update:

• Added the fixed gameplay banner below the Speed Bar for eligible ad-supported runs.
• Compacted successful leaderboard-save feedback so Results fit better on smaller phones.
• Tapping an unaffordable theme or companion now opens Buy Coins directly.
• Removed redundant shop instructions and status messages.
• Added clearer border accents to Leaderboard, Profile, and Settings.
• Changed beta interstitial testing to every three eligible completed runs.
• Corrected owner test-ad routing while retaining Google demo inventory for other testers.
• Included minor Pixel Theme fixes.

## Required URLs and ownership fields

- Support URL: **[PUBLISH AND ADD]**
- Privacy Policy URL: **[PUBLISH AND ADD]**
- Marketing URL: optional; **[ADD IF READY]**
- Terms URL: **[PUBLISH AND ADD]**
- Account-deletion help URL: **[PUBLISH AND ADD]**
- Copyright: `2026 [CONFIRMED RIGHTS-OWNING ENTITY]`
