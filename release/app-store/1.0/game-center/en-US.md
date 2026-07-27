# Game Center metadata — English (U.S.)

Status: configured for prerelease testing. The verified PimPoPom/Game Center binding, server publication consent, durable outbox, prerelease routing, and Turn Off behavior are implemented; physical delivery verification remains required before production release.

## Leaderboard

- Reference name: `Arcade`
- Vendor ID: `com.otcsoftware.pimpopom.arcade.verified`
- Display name: `Arcade`
- Description: `Global Arcade high scores.`
- Score format: integer, high to low
- Submission model: Hostinger-owned mirror of the player's accepted all-time Arcade best; never a direct iOS submission

Apple owns the **Prerelease** panel shown before a Game Center component is submitted and live. Changing the description does not remove that panel.

## Achievements

All five are visible and nonrepeatable. Point values total 100. Apple makes live achievement IDs permanent and point values immutable, so review this table before first submission.

| Reference/display name | Vendor ID | Points | Pre-earned description | Earned description |
| --- | --- | ---: | --- | --- |
| Complete Arcade | `com.otcsoftware.pimpopom.achievement.complete_arcade` | 10 | Finish an eligible signed-in Arcade run. | You finished an Arcade run. |
| Godlike Speed | `com.otcsoftware.pimpopom.achievement.godlike_speed` | 25 | Make a correct Arcade tap in under 250ms. | You landed a Godlike tap in under 250ms. |
| Collect 5 Coins | `com.otcsoftware.pimpopom.achievement.collect_5_coins` | 15 | Earn five coins through play and achievement rewards. | You earned five coins. |
| Score More Than 100K | `com.otcsoftware.pimpopom.achievement.score_over_100k` | 40 | Score more than 100,000 points in one Arcade run. | You scored more than 100,000 points. |
| Buy a Pet | `com.otcsoftware.pimpopom.achievement.buy_a_pet` | 10 | Purchase any pet from the Pet Shop. | You welcomed a pet. |

Each record also needs an original 1024×1024 RGB PNG or JPEG image. The storefront launch-kit backgrounds and app icon are not automatically suitable as achievement art; make five clearly distinguishable square images before configuration.

The server maps `claimable` and `claimed` to 100%. It submits nothing for `locked` and never sends 0%. Completion follows the authoritative goal unlock, not the separate in-app coin-claim action.
