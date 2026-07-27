# Game Center server-publication bug report

Date observed: 2026-07-27
Native build used for diagnosis: `1.2 (11)`
Bundle ID: `com.otcsoftware.pimpopom`

## Summary

The native flow is reaching PHP successfully. The connected iPhone has a verified one-to-one Game Center binding, publication consent is enabled, an Arcade result and four unlocked achievements were enqueued, and the minute cron is running. Apple rejected all five server submissions, so this is not a missing `GKLeaderboard.submitScore` or `GKAchievement.report` call in iOS.

Keep the accepted server-authoritative design: PHP publishes protocol-verified results and achievements. Do not work around this by trusting client-authored GameKit submissions.

## Live evidence

The live outbox contained five `HELD` rows after one delivery attempt:

| Submission | Apple HTTP status | Apple error code |
| --- | ---: | --- |
| Arcade leaderboard best | `409` | `ENTITY_ERROR.ATTRIBUTE.TYPE` |
| `complete_arcade` achievement | `403` | `FORBIDDEN_ERROR` |
| `godlike_speed` achievement | `403` | `FORBIDDEN_ERROR` |
| `buy_a_pet` achievement | `403` | `FORBIDDEN_ERROR` |
| `collect_5_coins` achievement | `403` | `FORBIDDEN_ERROR` |

The publisher cron is enabled once per minute. Its latest run claimed and delivered zero jobs because these rows are held rather than pending. Repeatedly running the worker will not repair them.

App Store Connect was also checked:

- Game Center is enabled for PimPoPom.
- The Arcade leaderboard vendor ID matches the backend allowlist.
- All five achievement vendor IDs match the backend allowlist.
- The leaderboard and achievements currently show `READY_FOR_REVIEW`.
- TestFlight publication is using the prerelease lane.

## Required leaderboard correction

The current PHP request encodes the leaderboard `score` attribute as a JSON number. Apple's current endpoint example for `POST /v1/gameCenterLeaderboardEntrySubmissions` encodes `score` as a JSON string. The live `ENTITY_ERROR.ATTRIBUTE.TYPE` rejection is consistent with that mismatch.

Change the outbound attribute from the equivalent of:

```php
'score' => $score,
```

to:

```php
'score' => (string) $score,
```

Update the deterministic request-body test to require a JSON string. Apple's separate schema page and endpoint example are inconsistent; the endpoint example plus the live rejection should govern this integration.

Reference: [Submit a leaderboard entry](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-gamecenterleaderboardentrysubmissions).

## Required achievement diagnosis

The achievement payload shape matches Apple's documented submission example, so the stored `403 FORBIDDEN_ERROR` is not specific enough to choose a safe fix. The HTTP error parser currently discards Apple's useful `errors[0].title`, `errors[0].detail`, and `errors[0].source`.

Before retrying:

1. Retain a sanitized form of Apple `title`, `detail`, and `source.pointer` in the held-job diagnostic. Do not retain JWTs, private keys, raw player IDs, or full request bodies.
2. Requeue one held achievement submission.
3. Run the publisher once and capture the complete sanitized Apple error.
4. Use that detail to distinguish App Store Connect key permissions from Game Center component/app-version review association.

Reference: [Submit a player achievement](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-gamecenterplayerachievementsubmissions).

Apple requires first Game Center components to be submitted with an app version for review. `READY_FOR_REVIEW` means the metadata is prepared, not approved. Verify the app-version association before treating the `403` as a code bug: [Submit Game Center components](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-game-center-components).

## Safe recovery order

1. Deploy the leaderboard string correction and expanded sanitized Apple error logging from a clean backend commit.
2. Requeue only the held leaderboard row and one held achievement row.
3. Run the publisher once.
4. Confirm the leaderboard row becomes delivered.
5. Inspect the full achievement rejection and correct the indicated App Store Connect permission/review configuration.
6. Requeue the remaining held achievement rows only after that correction.
7. Confirm `pendingJobs == 0`, `heldJobs == 0`, and the expected entries appear in Apple's dashboard.

No player, wallet, purchase, PHP leaderboard, or achievement records need to be deleted to repair this delivery problem.
