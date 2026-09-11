# Railway EU beta deployment

The owner-authorized EU service and PHP verifier were updated on 2026-09-11 for
TestFlight build 28. Hosted release and boundary checks passed; Apple approved
build 28 for the existing Internal QA and External QA groups. Real-player match
acceptance remains a separate gate.

## Provisioned target

| Item | Value |
| --- | --- |
| Workspace | bloodyvlad's Projects |
| Project | PimPoPom (`e7516d98-16d5-4db9-822c-480caa0625ba`) |
| Environment | production (`5c9fb522-0a21-48fd-bff9-4046f6ad3ae8`); unranked beta workload |
| Service | multiplayer-eu (`dacfc84e-bebe-429d-9ead-0387427b2cda`) |
| Region | Amsterdam, `europe-west4-drams3a`; Railway currently has no Spain region |
| Authority | Exactly one instance; do not add regional or horizontal replicas |
| Public socket | `wss://multiplayer-eu-production.up.railway.app/multiplayer/v2` |
| Health | `https://multiplayer-eu-production.up.railway.app/health` |
| Volume | `1e2262c1-9f41-4d85-acef-ed8dd245bcc6`, mounted at `/app/data`, initial 500 MB |
| Billing at setup | Trial, $5 credit/30 days; no paid subscription activated by this task |

The native client obtains the socket URL from the authenticated PHP ticket
response. Its HTTP backend remains `https://speedytapper.otcsoft.com`.

## Runtime configuration

The repository-root Docker build uses `Server/Dockerfile`. Upload an allowlisted
`git archive` of a reviewed clean commit, never the entire working checkout.
Include the Server manifests, sources, tests and startup scripts plus the shared
core manifest, sources and tests. Exclude app assets, local configuration, build
outputs, Git metadata and credentials.

Set both `PORT=8080` and `MP2_PORT=8080`, `MP2_BIND=0.0.0.0`, and
`RAILWAY_DOCKERFILE_PATH=Server/Dockerfile`. The domain target port is 8080.
Set `MP2_OUTBOX_DIRECTORY=/app/data/outbox`.

Railway mounts its volume as root. `RAILWAY_RUN_UID=0` is only a startup permission
bridge: the checked-in entrypoint must initialize the exact private outbox
directories and drop to UID/GID 10001 before starting the game service. Verify
the running process identity and an actual write/rename/read/delete probe. A
healthy process without writable durable storage is not deployment acceptance.
Never enable `MP2_DEV_AUTH` on this host.

The following endpoints must be deployed on the separate PHP host:

- `MP2_TICKET_INTROSPECTION_URL=https://speedytapper.otcsoft.com/api/internal/multiplayer/v2/tickets/redeem`
- `MP2_SESSION_VALIDATION_URL=https://speedytapper.otcsoft.com/api/internal/multiplayer/v2/sessions/validate`
- `MP2_RESULTS_URL=https://speedytapper.otcsoft.com/api/internal/multiplayer/v2/results`

`MP2_SERVICE_KEY` is a private service variable. PHP uses the same value as
`SPEEDYTAPPER_MULTIPLAYER_SERVICE_SECRET`, and the public socket URL above as
`SPEEDYTAPPER_REALTIME_URL`. Keep the key out of URLs, source, command arguments,
release records and logs. Pass it through stdin/private configuration only.
PHP migration 023 is required for v2. Additive migration 024 must also be applied
before gameplay revision 2 serves heart-enabled matches: cumulative misses can
exceed three when hearts restore lives. Live lives remain capped at three.

## Deployment and operation

- Serverless/sleep is disabled. Healthcheck `/health`, timeout 120 seconds.
- Restart policy: On Failure, ten retries (compatible with the trial).
- One instance, zero deployment overlap, 30-second SIGTERM grace. This grace is
  not implemented live-match migration or guaranteed completion draining.
- The volume survives restarts; live rooms do not. Redeploy only when no match
  is running, or explicitly communicate the infrastructure interruption.
- The result outbox survives and retries acknowledgements. It is unranked and
  cannot award coins, achievements or Game Center scores.
- Railway's deployment healthcheck is not continuous uptime monitoring.
- Trial expiry, account networking restrictions, memory use, CPU cost and
  remaining credit must be checked before sustained QA. No auto-upgrade is assumed.

Railway settings were applied through its official CLI/API rather than adding
the legacy `railway.json` format, which current Railway documentation deprecates.
Inspect the exact service's environment configuration and deployment metadata
before future releases. Do not apply a whole-environment config containing
unreviewed variable or service changes.

## Acceptance and rollback

Record the source SHA, allowlisted archive SHA-256, Railway deployment ID, image
identity, region, actual process UID, health/WSS checks and outbox restart proof.
Verify PHP migration ledger, service authentication, normal session/CSRF gates,
and matching configuration without logging secrets. Reject synthetic development
tickets on the hosted service. Unit and local fixture tests do not prove real
account sign-in, physical latency, or an entire internet match.

Before uploading iOS, run the source gate and inspect the Staging archive. Assign
the processed build to both existing QA groups and submit external Beta App
Review when required. Report assignment and approval separately; do not create
or change a public testing link.

The prior Railway deployment `920bd2bf-217e-44b3-ac4c-d3a0f964b812` is the
runtime rollback reference. It retains revision 2 but lacks room discovery/private
support; the new app capability gate prevents silent public creation. A rollback
restores an earlier image, not live room memory. Coordinate client compatibility
and PHP admission before rolling back. Retain the volume,
PHP backups and additive 023/024 schema. Old PHP's three-miss validation must not
receive revision-2 heart results. Never drop v2 tables as routine rollback.

## Current build 28 deployment evidence

Verified 2026-09-11, before the iOS upload. No hosting settings, secrets, regions,
plans, volume, schema or account data changed.

| Evidence | Value |
| --- | --- |
| Clean service source | `e866409c6571dd08069db76fabcd07d79016a487`; Server/Core identical in uploaded iOS `3922867` |
| Deployment | `3041f2bb-70f4-4a71-8318-039fb8e6aedb`, SUCCESS; one Amsterdam replica |
| Source tar SHA-256 | `0ac45cfa8797b49996601a76f176af3e3049b51a22713afbf89be37b4f6d39ed` |
| Railway image/index digest | `sha256:959ee011ddd0baeb71642e679b33e8e310b8c47ee379c91d6bdaebcf87784e0b` |
| Runtime binary SHA-256 | `9a5d3b08a66dfce6d1b2a6feed494c87627f2bdf65178ce51675e6b128bd91c1` |
| PHP source | `f84dc9218b58bb937326be931f2ee969abed4282`; schema 001–024 unchanged |
| PHP target | Only `speedytapper.otcsoft.com` / `/home/u966828068/domains/speedytapper.otcsoft.com/public_html` |

Linux ARM64 passed 40 service and 89 core tests plus entrypoint/readiness checks.
The local AMD64 QEMU compiler crashed before its unit gate; this is not an AMD64
unit-test pass. Railway's native AMD64 release build succeeded, and direct pinned
SSH verified x86_64, the exact deployment/replica, PID 1 UID/GID 10001, NoNewPrivs,
real 0700 outbox directories and the read-write ext4 mount. Startup readiness passed;
no extra result write, result enumeration or restart was performed.

Ten live WSS/auth boundaries passed with zero rooms/connections before and after.
Before/after configuration, deployment settings and secret fingerprints matched.
The exact temporary SSH registration and local key material were removed, with
a fresh empty workspace-key inventory matching the baseline. Full evidence is
`build/releases/build28-20260911/linux-verify.gJC9GU/VERIFICATION.md`.
PHP's 69 source hashes and 35 HTTPS checks passed before upload; see
`docs/RELEASE.md` for artifact, compatible v3/v4/v5 admission and rollback limits.
No positive real-account hosted match or physical-device latency is implied.

## Historical build 26 deployment evidence

Verified 2026-09-10; PHP 024 was directly verified before Railway activation.

| Evidence | Value |
| --- | --- |
| Clean service source | `6629fe09f31d34584ec39e49e99b49633bf035ea` |
| Railway deployment | `920bd2bf-217e-44b3-ac4c-d3a0f964b812`, SUCCESS around 19:19 UTC, one Amsterdam replica |
| Source tar SHA-256 | `a4c8aff288239aa3387beaa6d2e403f2e0a55c5f35b15c3714521618a4a3f74c` |
| Linux/amd64 image manifest | `sha256:6e4f4764f539d9a82be9d8bdc07f34236fee1a78c26286b1eb4bb6cab6acd204` |
| Railway image/index digest | `sha256:dfc2849ff5001edd5da45218bc65d8a4f1c55885dd19382f0b5c37c4baab7081` |
| Runtime binary SHA-256 | `126e137265c98077fe2cb9acbecef4b93f41df2a88b58a5c59a64dc8135879ad` |
| PHP deployed source | `9fe555d179326cecd5e23f0a6a16788b4af0ba34` |
| PHP artifact SHA-256 | `080b96234b290687ddc5b3f38c88881209f640cf423766fbbfe524e3179f99c5` |
| PHP host/root | `speedytapper.otcsoft.com` / `/home/u966828068/domains/speedytapper.otcsoft.com/public_html` |
| PHP migration/season | Ledger 001–024 directly verified; only 024 newly applied, season-1 unchanged |
| PHP rollback artifact SHA-256 | `dbea09d4c9e29f36d4140614073dbf71a6fc4d9c0c77e50acc3b779da2007882` (pre-build-26 runtime, tested readable, not redeployed) |

Fresh read-only Railway SSH verified x86_64 and PID 1 PimPoPomRealtime running as
UID/GID 10001, `NoNewPrivs=1`, with owner-only 0700 outbox/archive directories on
the writable ext4 volume. Startup's own write/rename/read readiness check passed.
No extra restart or result mutation was performed in this verification. The
temporary SSH registration and private material were removed; the pinned host key
matched the previous first-use record, not an independently published key.

Health reported ranking disabled and zero rooms/connections before/after ten live
WSS boundary tests. Both legacy and revision-2 invalid tickets reached the expected
authenticated rejection, development tickets remained disabled, and PHP passed
35 TLS/session/service-auth/private-path boundary checks. These do not establish
positive player sign-in, real-device latency or complete hosted-match delivery.
The 43-second positive heart/color/decoy match used local fixture accounts only.

The one-replica, sleep-disabled, 120-second healthcheck, zero-overlap, 30-second
drain and On Failure/10 settings were verified unchanged. No service secrets,
billing plan, existing workers, account data or economy values were changed.
Private PHP runtime/config/database backups were hash-verified; all temporary
deployment cron jobs and the bootstrap helper were removed from the live site.

Artifacts: `build/releases/build26-20260910/`; separate PHP release/backup record:
`/Users/vlad/Documents/SpeedyTapper-release-artifacts/20260910-mp26.S14gtt/RELEASE.md`.
Final uploaded iOS source `6a94d64312b113c8013782aca0a3ea8c8718eaf9` contains no
Server/Core changes from the deployed service source above.

## Historical build 25 deployment evidence

Verified 2026-09-09:

| Evidence | Value |
| --- | --- |
| Clean source | `962a39de80277534dd45eca56ca913217bde1fbb` |
| Railway deployment | `ece352a2-d7e1-4512-9f16-aad11daa6602`, SUCCESS, one Amsterdam replica |
| Source tar SHA-256 | `eceb9ffdf5579f2c20b38b266095c933ed5dd09c98a9db9e9abed1dcc5e213aa` |
| Linux/amd64 image digest | `sha256:02c4d013abeed5e7561d2983a19e848dca5833661ddab039fec40f9fbccc7946` |
| Runtime binary SHA-256 | `da99b0015ff7899a40867baf28bef9c45a9764ecd27283bb4af0dbad4c0a25ec` |
| PHP deployed source | `78b51ee6768d6f049d44b3b8c2d2073e0aac34e0` |
| PHP artifact SHA-256 | `dd5a9ad241d0cd1dce7da9bf1389c130d558bcc4a035a1135e5097f2bccce5c7` |
| PHP migration/season | 023 applied; existing 001–022 already present; season-1 unchanged |

Public TLS health returned protocol 2, `multiplayer-shared-arcade-v2`, ranking
disabled and zero rooms/connections. Negative WSS checks rejected no-hello,
pre-hello Create, development tickets and the wrong protocol. One ping/pong was
52 ms; this isolated sample is not a gameplay-latency benchmark.

Runtime PID 1 was UID/GID 10001 with `NoNewPrivs=1`. Outbox/archive directories
were owner-only 0700 on the `/app/data` ext4 mount. An exact own 43-byte non-JSON
probe survived one controlled empty-service restart with its hash unchanged,
then was removed as UID 10001. No result JSON was created or altered by the test.

Railway-to-PHP HTTPS accepted the real service key and reached the expected
nonexistent-ticket rejection, with CA/hostname verification enabled. The key was
sent through TLS stdin, never arguments/logs. PHP passed 35 live boundary checks,
including service authentication, normal session/CSRF/origin gates, retained API
compatibility and private-path denial. This does not establish successful player
sign-in, a complete hosted match, reconnect/revocation, or real result delivery.

Temporary Railway SSH registration/material and all temporary Hostinger cron jobs
were removed; original workers and SSH configuration were preserved. SSH used
task-local, strict first-use host-key pinning, not an independently published key.
The first attempted Railway deployment failed before building because Dockerfile
`VOLUME` declarations are unsupported; only the successful source above is live.

Retained local artifacts/logs: `build/releases/build25-20260909/`. The separate PHP
release/rollback record is
`/Users/vlad/Documents/SpeedyTapper-release-artifacts/20260909-v2.cwDiG8/RELEASE.md`.
See [iOS release state](../docs/RELEASE.md) for Apple processing/review evidence.

Sources checked 2026-09-09: [regions](https://docs.railway.com/deployments/regions),
[volumes](https://docs.railway.com/volumes),
[healthchecks](https://docs.railway.com/deployments/healthchecks),
[trial](https://docs.railway.com/pricing/free-trial),
[legacy configuration](https://docs.railway.com/config-as-code/reference).
