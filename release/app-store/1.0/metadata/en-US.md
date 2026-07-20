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
