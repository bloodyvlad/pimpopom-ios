# Game Center metadata — English (U.S.)

Status: configured for prerelease/TestFlight. PHP owns publication; iOS opens the
dashboard but never submits scores or achievements directly. Production association
and physical delivery verification remain open.

## Leaderboards

| Display | Vendor ID | Description | Source |
| --- | --- | --- | --- |
| Arcade | `com.otcsoftware.pimpopom.arcade.verified` | Global Arcade high scores. | PHP-published accepted personal best |
| Multiplayer | `com.otcsoftware.pimpopom.multiplayer.verified` | Global Multiplayer high scores. | PHP-published peer-consistent personal best |

Both use integer, high-to-low scoring. Apple may show a Prerelease label until the
component is submitted and live.

## Achievements

All five are visible, nonrepeatable, and total 100 points.

| Name | Vendor ID | Points | Pre-earned / earned copy |
| --- | --- | ---: | --- |
| Complete Arcade | `com.otcsoftware.pimpopom.achievement.complete_arcade` | 10 | Finish an eligible signed-in Arcade run. / You finished an Arcade run. |
| Godlike Speed | `com.otcsoftware.pimpopom.achievement.godlike_speed` | 25 | Make a correct Arcade tap in under 250 ms. / You landed a Godlike tap. |
| Collect 5 Coins | `com.otcsoftware.pimpopom.achievement.collect_5_coins` | 15 | Earn five eligible coins. / You earned five coins. |
| Score More Than 100K | `com.otcsoftware.pimpopom.achievement.score_over_100k` | 40 | Score over 100,000 in one eligible Arcade run. / You scored over 100,000. |
| Buy a Pet | `com.otcsoftware.pimpopom.achievement.buy_a_pet` | 10 | Purchase any pet. / You welcomed a pet. |

PHP maps authoritative `claimable`/`claimed` to 100%, publishes nothing for locked,
and does not confuse the separate in-app coin claim with unlock. Each achievement
still needs final accepted 1024×1024 RGB artwork before production submission.
